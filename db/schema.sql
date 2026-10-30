-- ============================================================================
-- FOOTBALL VALUE AI — Schéma PostgreSQL 16 (Phase 1, référence)
-- ----------------------------------------------------------------------------
-- Conventions :
--   * Horodatages TIMESTAMPTZ en UTC.
--   * Montants et probabilités en NUMERIC (jamais FLOAT).
--   * line = 0 signifie "aucune ligne" (1X2, BTTS, DC, DNB, CS...).
--   * Tables de faits (cotes, prédictions, événements, audit) append-only.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
CREATE TYPE match_status AS ENUM (
  'scheduled','live','halftime','finished','postponed','cancelled',
  'suspended','abandoned','unknown'
);
CREATE TYPE access_channel AS ENUM ('api','manual','partner');
CREATE TYPE model_status AS ENUM ('candidate','active','archived','rolled_back');
CREATE TYPE priority_level AS ENUM ('A','B','C','D','NO_BET');
CREATE TYPE value_status AS ENUM ('active','expired','withdrawn','settled');
CREATE TYPE value_event_type AS ENUM (
  'created','upgraded','downgraded','expired','withdrawn','settled'
);
CREATE TYPE bet_status AS ENUM ('pending','won','lost','void','half_won','half_lost');
CREATE TYPE favorite_entity AS ENUM ('match','team','competition');
CREATE TYPE notification_channel AS ENUM ('push','in_app');
CREATE TYPE notification_status AS ENUM ('queued','sent','failed','read');

-- ---------------------------------------------------------------------------
-- Fonctions utilitaires
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Table % est append-only : % interdit', TG_TABLE_NAME, TG_OP;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Référentiel
-- ---------------------------------------------------------------------------
CREATE TABLE data_sources (
  id                  SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                TEXT NOT NULL UNIQUE,          -- 'the_odds_api', 'api_football', 'lonabet_manual'
  name                TEXT NOT NULL,
  kind                TEXT NOT NULL,                 -- 'fixtures','stats','odds','live','notifications'
  is_enabled          BOOLEAN NOT NULL DEFAULT FALSE,
  license_ref         TEXT,                          -- référence contractuelle, jamais un secret
  reliability_weight  NUMERIC(4,3) NOT NULL DEFAULT 0.500 CHECK (reliability_weight BETWEEN 0 AND 1),
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE competitions (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code            TEXT NOT NULL UNIQUE,              -- 'EPL','LIGUE1','CAN'
  name            TEXT NOT NULL,
  country_code    TEXT NOT NULL,                     -- ISO 3166-1 alpha-2
  logo_url        TEXT,
  tier            SMALLINT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE seasons (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  competition_id  INTEGER NOT NULL REFERENCES competitions(id),
  label           TEXT NOT NULL,                     -- '2026/2027'
  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  is_current      BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (competition_id, label),
  CHECK (end_date > start_date)
);
CREATE UNIQUE INDEX seasons_one_current_per_competition
  ON seasons (competition_id) WHERE is_current;

CREATE TABLE teams (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code            TEXT UNIQUE,
  name            TEXT NOT NULL,
  short_name      TEXT,
  country_code    TEXT,
  logo_url        TEXT,
  external_refs   JSONB NOT NULL DEFAULT '{}'::jsonb, -- {"api_football": 42, "odds_api": "Arsenal"}
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE players (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id         INTEGER REFERENCES teams(id),
  name            TEXT NOT NULL,
  position        TEXT,
  birth_date      DATE,
  external_refs   JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE venues (
  id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  city        TEXT,
  country_code TEXT,
  capacity    INTEGER,
  timezone    TEXT NOT NULL DEFAULT 'UTC'
);

CREATE TABLE matches (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  competition_id    INTEGER NOT NULL REFERENCES competitions(id),
  season_id         INTEGER REFERENCES seasons(id),
  round             TEXT,
  kickoff_utc       TIMESTAMPTZ NOT NULL,
  kickoff_local     TIMESTAMP,                        -- heure locale d'origine (sans fuseau)
  venue_timezone    TEXT NOT NULL DEFAULT 'UTC',
  venue_id          INTEGER REFERENCES venues(id),
  home_team_id      INTEGER NOT NULL REFERENCES teams(id),
  away_team_id      INTEGER NOT NULL REFERENCES teams(id),
  status            match_status NOT NULL DEFAULT 'scheduled',
  minute            SMALLINT CHECK (minute BETWEEN 0 AND 130),
  home_score        SMALLINT CHECK (home_score >= 0),
  away_score        SMALLINT CHECK (away_score >= 0),
  home_score_ht     SMALLINT CHECK (home_score_ht >= 0),
  away_score_ht     SMALLINT CHECK (away_score_ht >= 0),
  data_quality_score NUMERIC(4,3) NOT NULL DEFAULT 0 CHECK (data_quality_score BETWEEN 0 AND 1),
  source_id         SMALLINT NOT NULL REFERENCES data_sources(id),
  source_event_id   TEXT NOT NULL,
  last_synced_at    TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source_id, source_event_id),
  CHECK (home_team_id <> away_team_id)
);
CREATE INDEX matches_kickoff_idx ON matches (kickoff_utc);
CREATE INDEX matches_competition_kickoff_idx ON matches (competition_id, kickoff_utc);
CREATE INDEX matches_live_idx ON matches (status, kickoff_utc) WHERE status IN ('live','halftime');

CREATE TABLE team_match_stats (
  match_id            BIGINT NOT NULL REFERENCES matches(id),
  team_id             INTEGER NOT NULL REFERENCES teams(id),
  source_id           SMALLINT NOT NULL REFERENCES data_sources(id),
  is_home             BOOLEAN NOT NULL,
  possession          NUMERIC(5,2) CHECK (possession BETWEEN 0 AND 100),
  shots               SMALLINT CHECK (shots >= 0),
  shots_on_target     SMALLINT CHECK (shots_on_target >= 0),
  corners             SMALLINT CHECK (corners >= 0),
  yellow_cards        SMALLINT CHECK (yellow_cards >= 0),
  red_cards           SMALLINT CHECK (red_cards >= 0),
  fouls               SMALLINT CHECK (fouls >= 0),
  offsides            SMALLINT CHECK (offsides >= 0),
  xg                  NUMERIC(5,2),
  xga                 NUMERIC(5,2),
  passes              INTEGER,
  pass_accuracy       NUMERIC(5,2),
  is_preferred        BOOLEAN NOT NULL DEFAULT FALSE,
  observed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, team_id, source_id),
  CHECK (shots_on_target IS NULL OR shots IS NULL OR shots_on_target <= shots)
);

CREATE TABLE player_match_stats (
  match_id        BIGINT NOT NULL REFERENCES matches(id),
  player_id       INTEGER NOT NULL REFERENCES players(id),
  team_id         INTEGER NOT NULL REFERENCES teams(id),
  source_id       SMALLINT NOT NULL REFERENCES data_sources(id),
  minutes         SMALLINT CHECK (minutes BETWEEN 0 AND 130),
  goals           SMALLINT NOT NULL DEFAULT 0,
  assists         SMALLINT NOT NULL DEFAULT 0,
  shots           SMALLINT NOT NULL DEFAULT 0,
  shots_on_target SMALLINT NOT NULL DEFAULT 0,
  rating          NUMERIC(3,1),
  PRIMARY KEY (match_id, player_id, source_id)
);

CREATE TABLE injuries (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  player_id       INTEGER NOT NULL REFERENCES players(id),
  team_id         INTEGER NOT NULL REFERENCES teams(id),
  status          TEXT NOT NULL,                     -- 'injured','suspended','doubtful','returned'
  description     TEXT,
  start_date      DATE,
  expected_return DATE,
  source_id       SMALLINT NOT NULL REFERENCES data_sources(id),
  observed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX injuries_team_idx ON injuries (team_id, status);

CREATE TABLE lineups (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id        BIGINT NOT NULL REFERENCES matches(id),
  team_id         INTEGER NOT NULL REFERENCES teams(id),
  formation       TEXT,
  is_official     BOOLEAN NOT NULL DEFAULT FALSE,
  published_at    TIMESTAMPTZ,
  source_id       SMALLINT NOT NULL REFERENCES data_sources(id),
  UNIQUE (match_id, team_id, source_id)
);

CREATE TABLE lineup_players (
  lineup_id   BIGINT NOT NULL REFERENCES lineups(id) ON DELETE CASCADE,
  player_id   INTEGER NOT NULL REFERENCES players(id),
  is_starter  BOOLEAN NOT NULL,
  position    TEXT,
  shirt_number SMALLINT,
  PRIMARY KEY (lineup_id, player_id)
);

-- ---------------------------------------------------------------------------
-- Bookmakers, marchés, cotes
-- ---------------------------------------------------------------------------
CREATE TABLE bookmakers (
  id              SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code            TEXT NOT NULL UNIQUE,              -- 'onexbet','pinnacle','lonabet'
  name            TEXT NOT NULL,
  countries       TEXT[] NOT NULL DEFAULT '{}',      -- pays où l'opérateur est accessible
  access_channel  access_channel NOT NULL,
  logo_url        TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE markets (
  id                SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code              TEXT NOT NULL UNIQUE,            -- '1X2','OU','BTTS','AH','DC','DNB','CS','HT_1X2','CORNERS_OU','CARDS_OU','PLAYER_GOALS'
  name              TEXT NOT NULL,
  family            TEXT NOT NULL,                   -- 'result','goals','handicap','corners','cards','player'
  has_line          BOOLEAN NOT NULL DEFAULT FALSE,
  supports_live     BOOLEAN NOT NULL DEFAULT FALSE,
  supports_combo    BOOLEAN NOT NULL DEFAULT FALSE,
  settlement_rules  TEXT NOT NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE
);

-- Table de faits partitionnée par mois.
CREATE SEQUENCE odds_snapshots_seq;

CREATE TABLE odds_snapshots (
  snapshot_id         BIGINT NOT NULL DEFAULT nextval('odds_snapshots_seq'),
  match_id            BIGINT NOT NULL REFERENCES matches(id),
  bookmaker_id        SMALLINT NOT NULL REFERENCES bookmakers(id),
  market_code         TEXT NOT NULL REFERENCES markets(code),
  line                NUMERIC(6,2) NOT NULL DEFAULT 0,
  selection_code      TEXT NOT NULL,
  decimal_odds        NUMERIC(9,4) NOT NULL CHECK (decimal_odds > 1),
  implied_prob_raw    NUMERIC(9,8) GENERATED ALWAYS AS (1 / decimal_odds) STORED,
  is_live             BOOLEAN NOT NULL DEFAULT FALSE,
  is_verified         BOOLEAN NOT NULL DEFAULT FALSE,
  is_available        BOOLEAN NOT NULL DEFAULT TRUE,
  source_id           SMALLINT NOT NULL REFERENCES data_sources(id),
  source_payload_hash TEXT NOT NULL,
  observed_at         TIMESTAMPTZ NOT NULL,
  captured_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (snapshot_id, captured_at)
) PARTITION BY RANGE (captured_at);

CREATE TABLE odds_snapshots_2026_10 PARTITION OF odds_snapshots
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE odds_snapshots_2026_11 PARTITION OF odds_snapshots
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
-- Les partitions suivantes sont créées par un job mensuel (pg_partman ou tâche Celery).

CREATE INDEX odds_snap_match_market_idx
  ON odds_snapshots (match_id, market_code, selection_code, captured_at DESC);
CREATE INDEX odds_snap_bookmaker_idx
  ON odds_snapshots (bookmaker_id, captured_at DESC);
CREATE UNIQUE INDEX odds_snap_dedup_idx
  ON odds_snapshots (source_id, source_payload_hash, captured_at);

CREATE TRIGGER odds_snapshots_append_only
  BEFORE UPDATE OR DELETE ON odds_snapshots
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Dernière cote connue par sélection (à filtrer par fraîcheur côté requête).
CREATE VIEW odds_latest AS
SELECT DISTINCT ON (match_id, bookmaker_id, market_code, line, selection_code)
  snapshot_id, match_id, bookmaker_id, market_code, line, selection_code,
  decimal_odds, is_live, is_verified, is_available, source_id, observed_at, captured_at
FROM odds_snapshots
ORDER BY match_id, bookmaker_id, market_code, line, selection_code, captured_at DESC;

-- ---------------------------------------------------------------------------
-- Modèles et prédictions (immuables)
-- ---------------------------------------------------------------------------
CREATE TABLE model_versions (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code            TEXT NOT NULL,
  version         TEXT NOT NULL,
  algorithm       TEXT NOT NULL,                     -- 'dixon_coles','elo','xgboost','ensemble'
  markets         TEXT[] NOT NULL,
  trained_at      TIMESTAMPTZ NOT NULL,
  training_start  DATE NOT NULL,
  training_end    DATE NOT NULL,
  metrics         JSONB NOT NULL DEFAULT '{}'::jsonb,-- {"1X2":{"brier":0.19,"logloss":0.96,"ece":0.03}}
  calibration     JSONB NOT NULL DEFAULT '{}'::jsonb,
  artifact_uri    TEXT,
  checksum        TEXT,
  parent_id       INTEGER REFERENCES model_versions(id),
  status          model_status NOT NULL DEFAULT 'candidate',
  activated_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (code, version),
  CHECK (training_end > training_start)
);
CREATE UNIQUE INDEX model_versions_one_active
  ON model_versions ((code)) WHERE status = 'active';

CREATE TABLE prediction_contexts (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id        BIGINT NOT NULL REFERENCES matches(id),
  model_version_id INTEGER NOT NULL REFERENCES model_versions(id),
  features        JSONB NOT NULL,
  features_hash   TEXT NOT NULL,
  feature_cutoff  TIMESTAMPTZ NOT NULL,              -- aucune donnée postérieure à cet instant
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, model_version_id, features_hash)
);

CREATE TABLE predictions (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id          BIGINT NOT NULL REFERENCES matches(id),
  model_version_id  INTEGER NOT NULL REFERENCES model_versions(id),
  context_id        BIGINT REFERENCES prediction_contexts(id),
  market_code       TEXT NOT NULL REFERENCES markets(code),
  line              NUMERIC(6,2) NOT NULL DEFAULT 0,
  selection_code    TEXT NOT NULL,
  probability       NUMERIC(7,6) NOT NULL CHECK (probability > 0 AND probability < 1),
  ci_low            NUMERIC(7,6) NOT NULL CHECK (ci_low > 0 AND ci_low < 1),
  ci_high           NUMERIC(7,6) NOT NULL CHECK (ci_high > 0 AND ci_high <= 1),
  fair_odds         NUMERIC(9,4) NOT NULL CHECK (fair_odds > 1),
  data_quality_score NUMERIC(4,3) NOT NULL CHECK (data_quality_score BETWEEN 0 AND 1),
  uncertainty        NUMERIC(7,6) NOT NULL CHECK (uncertainty BETWEEN 0 AND 1),
  supersedes_id     BIGINT REFERENCES predictions(id),
  features_hash     TEXT NOT NULL,
  prev_hash         TEXT,
  row_hash          TEXT NOT NULL,
  explanation       JSONB NOT NULL DEFAULT '{}'::jsonb,
  predicted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ci_low <= probability AND probability <= ci_high),
  CHECK (fair_odds = round((1 / probability)::numeric, 4)),
  UNIQUE (match_id, model_version_id, market_code, line, selection_code)
);
CREATE INDEX predictions_match_idx ON predictions (match_id, market_code);
CREATE INDEX predictions_model_idx ON predictions (model_version_id, predicted_at DESC);

CREATE TRIGGER predictions_append_only
  BEFORE UPDATE OR DELETE ON predictions
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE calibration_bins (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  model_version_id  INTEGER NOT NULL REFERENCES model_versions(id),
  market_code       TEXT NOT NULL,
  period_start      DATE NOT NULL,
  period_end        DATE NOT NULL,
  bin_lower         NUMERIC(5,4) NOT NULL,
  bin_upper         NUMERIC(5,4) NOT NULL,
  n_predictions     INTEGER NOT NULL,
  mean_predicted    NUMERIC(6,4) NOT NULL,
  observed_rate     NUMERIC(6,4) NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (bin_lower < bin_upper),
  CHECK (observed_rate BETWEEN 0 AND 1)
);

-- ---------------------------------------------------------------------------
-- Seuils et Value Betting
-- ---------------------------------------------------------------------------
CREATE TABLE value_thresholds (
  id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  market_code       TEXT NOT NULL REFERENCES markets(code),
  min_ev            NUMERIC(6,4) NOT NULL,           -- 0.0300 = +3 %
  min_ev_lower      NUMERIC(6,4) NOT NULL,           -- borne basse de l'IC de l'EV
  max_margin        NUMERIC(6,4) NOT NULL,           -- marge bookmaker max tolérée
  min_data_quality  NUMERIC(4,3) NOT NULL,
  min_odds          NUMERIC(9,4) NOT NULL,
  max_odds          NUMERIC(9,4) NOT NULL,
  max_age_seconds   INTEGER NOT NULL,
  valid_from        TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to          TIMESTAMPTZ,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  CHECK (min_ev_lower <= min_ev),
  CHECK (min_odds > 1),
  CHECK (max_odds > min_odds),
  CHECK (max_age_seconds > 0)
);
CREATE UNIQUE INDEX value_thresholds_active_per_market
  ON value_thresholds (market_code) WHERE is_active AND valid_to IS NULL;

CREATE TABLE value_bets (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id            BIGINT NOT NULL REFERENCES matches(id),
  prediction_id       BIGINT NOT NULL REFERENCES predictions(id),
  odds_snapshot_id    BIGINT NOT NULL,
  odds_captured_at    TIMESTAMPTZ NOT NULL,          -- clé de partition de la cote référencée
  bookmaker_id        SMALLINT NOT NULL REFERENCES bookmakers(id),
  market_code         TEXT NOT NULL REFERENCES markets(code),
  line                NUMERIC(6,2) NOT NULL DEFAULT 0,
  selection_code      TEXT NOT NULL,
  decimal_odds        NUMERIC(9,4) NOT NULL CHECK (decimal_odds > 1),
  implied_prob_novig  NUMERIC(7,6) NOT NULL CHECK (implied_prob_novig > 0 AND implied_prob_novig < 1),
  edge                NUMERIC(7,6) NOT NULL,         -- p_ia - p_novig
  fair_odds           NUMERIC(9,4) NOT NULL CHECK (fair_odds > 1),
  ev                  NUMERIC(9,6) NOT NULL,
  ev_lower            NUMERIC(9,6) NOT NULL,
  score               NUMERIC(5,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
  priority            priority_level NOT NULL,
  threshold_id        INTEGER REFERENCES value_thresholds(id),
  gate_results        JSONB NOT NULL DEFAULT '{}'::jsonb,
  explanation         JSONB NOT NULL DEFAULT '{}'::jsonb,
  status              value_status NOT NULL DEFAULT 'active',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at          TIMESTAMPTZ,
  FOREIGN KEY (odds_snapshot_id, odds_captured_at)
    REFERENCES odds_snapshots (snapshot_id, captured_at),
  CHECK (expires_at IS NULL OR expires_at > created_at)
);
CREATE INDEX value_bets_active_idx
  ON value_bets (priority, score DESC) WHERE status = 'active';
CREATE INDEX value_bets_match_idx ON value_bets (match_id, created_at DESC);
CREATE INDEX value_bets_snapshot_idx ON value_bets (odds_snapshot_id, odds_captured_at);

CREATE TABLE value_bet_events (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  value_bet_id  BIGINT NOT NULL REFERENCES value_bets(id),
  event_type    value_event_type NOT NULL,
  old_priority  priority_level,
  new_priority  priority_level,
  old_odds      NUMERIC(9,4),
  new_odds      NUMERIC(9,4),
  reason        TEXT NOT NULL,
  payload       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX value_bet_events_bet_idx ON value_bet_events (value_bet_id, created_at);

CREATE TRIGGER value_bet_events_append_only
  BEFORE UPDATE OR DELETE ON value_bet_events
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- ---------------------------------------------------------------------------
-- Utilisateurs, rôles, sécurité
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email           TEXT NOT NULL,
  password_hash   TEXT NOT NULL,                     -- Argon2id
  display_name    TEXT,
  locale          TEXT NOT NULL DEFAULT 'fr',
  timezone        TEXT NOT NULL DEFAULT 'Africa/Ouagadougou',
  status          TEXT NOT NULL DEFAULT 'active',    -- 'active','suspended','pending'
  email_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  failed_logins   SMALLINT NOT NULL DEFAULT 0,
  locked_until    TIMESTAMPTZ,
  last_login_at   TIMESTAMPTZ,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_lower_uidx ON users (lower(email));
CREATE INDEX users_deleted_idx ON users (deleted_at) WHERE deleted_at IS NOT NULL;

CREATE TABLE roles (
  id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code  TEXT NOT NULL UNIQUE,                        -- visitor,user,analyst,admin,service
  name  TEXT NOT NULL
);

CREATE TABLE permissions (
  id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code  TEXT NOT NULL UNIQUE
);

CREATE TABLE role_permissions (
  role_id       SMALLINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id SMALLINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
  user_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id   SMALLINT NOT NULL REFERENCES roles(id),
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  granted_by BIGINT REFERENCES users(id),
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE refresh_tokens (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash    TEXT NOT NULL UNIQUE,                -- hash, jamais le token
  device_label  TEXT,
  ip_hash       TEXT,
  issued_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL,
  revoked_at    TIMESTAMPTZ,
  replaced_by   BIGINT REFERENCES refresh_tokens(id),
  CHECK (expires_at > issued_at)
);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id, expires_at DESC);

CREATE TABLE devices (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform      TEXT NOT NULL DEFAULT 'android',
  fcm_token     TEXT,
  app_version   TEXT,
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, fcm_token)
);

CREATE TABLE favorites (
  user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type  favorite_entity NOT NULL,
  entity_id    BIGINT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entity_type, entity_id)
);

-- ---------------------------------------------------------------------------
-- Simulation
-- ---------------------------------------------------------------------------
CREATE TABLE bankrolls (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL DEFAULT 'Bankroll principale',
  currency        TEXT NOT NULL DEFAULT 'XOF',
  initial_amount  NUMERIC(14,2) NOT NULL CHECK (initial_amount > 0),
  current_amount  NUMERIC(14,2) NOT NULL CHECK (current_amount >= 0),
  kelly_fraction  NUMERIC(4,3) NOT NULL DEFAULT 0.250 CHECK (kelly_fraction BETWEEN 0 AND 0.5),
  max_stake_pct   NUMERIC(5,4) NOT NULL DEFAULT 0.010 CHECK (max_stake_pct BETWEEN 0 AND 0.05),
  max_daily_pct   NUMERIC(5,4) NOT NULL DEFAULT 0.050 CHECK (max_daily_pct BETWEEN 0 AND 0.10),
  staking_enabled BOOLEAN NOT NULL DEFAULT FALSE,    -- désactivé par défaut : l'utilisateur choisit
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX bankrolls_user_idx ON bankrolls (user_id) WHERE is_active;

CREATE TABLE bet_slips (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind                TEXT NOT NULL,                 -- 'single','same_match_combo','multi_match_combo'
  combined_odds       NUMERIC(12,4) NOT NULL CHECK (combined_odds > 1),
  joint_probability   NUMERIC(7,6) NOT NULL CHECK (joint_probability > 0 AND joint_probability < 1),
  correlation_model   TEXT,                          -- 'copula_score_matrix', 'none'
  ev                  NUMERIC(9,6) NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE bet_slip_legs (
  slip_id        BIGINT NOT NULL REFERENCES bet_slips(id) ON DELETE CASCADE,
  value_bet_id   BIGINT NOT NULL REFERENCES value_bets(id),
  PRIMARY KEY (slip_id, value_bet_id)
);

CREATE TABLE simulated_bets (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bankroll_id     BIGINT NOT NULL REFERENCES bankrolls(id) ON DELETE CASCADE,
  value_bet_id    BIGINT REFERENCES value_bets(id),
  slip_id         BIGINT REFERENCES bet_slips(id),
  stake           NUMERIC(14,2) NOT NULL CHECK (stake > 0),
  odds_taken      NUMERIC(9,4) NOT NULL CHECK (odds_taken > 1),
  status          bet_status NOT NULL DEFAULT 'pending',
  settled_at      TIMESTAMPTZ,
  payout          NUMERIC(14,2),
  pnl             NUMERIC(14,2),
  closing_odds    NUMERIC(9,4),
  clv             NUMERIC(9,6),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((value_bet_id IS NOT NULL) <> (slip_id IS NOT NULL)),
  CHECK ((status = 'pending') = (settled_at IS NULL))
);
CREATE INDEX simulated_bets_bankroll_idx ON simulated_bets (bankroll_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
CREATE TABLE notification_preferences (
  user_id        BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type           TEXT NOT NULL,                      -- 'value_A','value_B','odds_move','lineup','match_start','sync_alert'
  enabled        BOOLEAN NOT NULL DEFAULT TRUE,
  min_priority   priority_level NOT NULL DEFAULT 'B',
  quiet_start    TIME,
  quiet_end      TIME,
  PRIMARY KEY (user_id, type)
);

CREATE TABLE notifications (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  channel     notification_channel NOT NULL DEFAULT 'push',
  status      notification_status NOT NULL DEFAULT 'queued',
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  sent_at     TIMESTAMPTZ,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Exploitation
-- ---------------------------------------------------------------------------
CREATE TABLE ingestion_runs (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id     SMALLINT NOT NULL REFERENCES data_sources(id),
  job_type      TEXT NOT NULL,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at   TIMESTAMPTZ,
  status        TEXT NOT NULL DEFAULT 'running',     -- running,success,partial,failed
  records_in    INTEGER NOT NULL DEFAULT 0,
  records_upserted INTEGER NOT NULL DEFAULT 0,
  records_rejected INTEGER NOT NULL DEFAULT 0,
  error_code    TEXT,
  error_detail  TEXT,
  quota_remaining INTEGER
);
CREATE INDEX ingestion_runs_source_idx ON ingestion_runs (source_id, started_at DESC);

CREATE TABLE provider_health (
  source_id       SMALLINT PRIMARY KEY REFERENCES data_sources(id),
  last_success_at TIMESTAMPTZ,
  last_error_at   TIMESTAMPTZ,
  last_error      TEXT,
  latency_ms      INTEGER,
  error_rate_1h   NUMERIC(5,4),
  quota_remaining INTEGER,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE raw_payloads (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id   SMALLINT NOT NULL REFERENCES data_sources(id),
  endpoint    TEXT NOT NULL,
  http_status SMALLINT,
  payload     BYTEA,                                 -- gzip
  payload_hash TEXT NOT NULL,
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX raw_payloads_fetched_idx ON raw_payloads (fetched_at);
CREATE UNIQUE INDEX raw_payloads_dedup_idx ON raw_payloads (source_id, payload_hash);

CREATE TABLE audit_logs (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id    BIGINT REFERENCES users(id),
  actor_role  TEXT,
  action      TEXT NOT NULL,
  target      TEXT,
  result      TEXT NOT NULL,
  ip_hash     TEXT,
  metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_actor_idx ON audit_logs (actor_id, created_at DESC);
CREATE INDEX audit_logs_action_idx ON audit_logs (action, created_at DESC);

CREATE TRIGGER audit_logs_append_only
  BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE system_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  description TEXT,
  updated_by  BIGINT REFERENCES users(id),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Triggers updated_at
-- ---------------------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'data_sources','competitions','teams','players','matches','bookmakers','users','bankrolls'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I_updated_at BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $$;

-- ===========================================================================
-- Données de référence (aucune donnée sportive fictive)
-- ===========================================================================

INSERT INTO data_sources (code, name, kind, is_enabled, license_ref, reliability_weight) VALUES
  ('the_odds_api',    'The Odds API',              'odds',    FALSE, 'contrat à souscrire', 0.800),
  ('api_football',    'API-Football (API-Sports)', 'stats',   FALSE, 'contrat à souscrire', 0.850),
  ('lonabet_manual',  'Lonabet (saisie manuelle)', 'odds',    FALSE, 'usage personnel', 0.600),
  ('partner_feed',    'Flux partenaire (à définir)', 'live',  FALSE, NULL, 0.900);

INSERT INTO markets (code, name, family, has_line, supports_live, supports_combo, settlement_rules) VALUES
  ('1X2','Résultat 1X2','result',FALSE,TRUE,TRUE,'Temps réglementaire, prolongations exclues.'),
  ('DC','Double chance','result',FALSE,FALSE,TRUE,'Deux issues couvertes sur trois ; nul inclus selon la combinaison.'),
  ('DNB','Draw No Bet','result',FALSE,FALSE,TRUE,'Mise remboursée si match nul.'),
  ('AH','Handicap asiatique','handicap',TRUE,TRUE,FALSE,'Remboursement partiel ou total selon la ligne ; demi-lignes sans push.'),
  ('OU','Total de buts','goals',TRUE,TRUE,TRUE,'Temps réglementaire ; ligne 2.5 = strictement plus/moins de 2 buts.'),
  ('BTTS','Les deux équipes marquent','goals',FALSE,TRUE,TRUE,'Les deux équipes doivent marquer au moins un but.'),
  ('CS','Score exact','goals',FALSE,FALSE,FALSE,'Score final, temps réglementaire.'),
  ('HT_1X2','Résultat mi-temps','result',FALSE,FALSE,FALSE,'Score à la pause (45 min + arrêts).'),
  ('HT_OU','Total buts mi-temps','goals',TRUE,FALSE,FALSE,'Buts marqués en première mi-temps.'),
  ('CORNERS_OU','Total corners','corners',TRUE,FALSE,FALSE,'Corners comptés selon le règlement du bookmaker.'),
  ('CARDS_OU','Total cartons','cards',TRUE,FALSE,FALSE,'Cartons jaunes = 1, rouges = 2 sauf règle contraire du bookmaker.'),
  ('PLAYER_GOALS','Marchés joueurs buts','player',FALSE,FALSE,FALSE,'Titularisation et temps de jeu requis selon le bookmaker.');

INSERT INTO roles (code, name) VALUES
  ('visitor','Visiteur'),('user','Utilisateur'),('analyst','Analyste'),
  ('admin','Administrateur'),('service','Service');

INSERT INTO permissions (code) VALUES
  ('matches.read'),('predictions.read'),('value.read'),('favorites.write'),
  ('simulation.write'),('notifications.manage'),
  ('admin.users'),('admin.providers'),('admin.models'),('admin.thresholds'),
  ('admin.audit'),('admin.backup');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE (r.code = 'visitor' AND p.code IN ('matches.read','predictions.read'))
   OR (r.code = 'user'    AND p.code IN ('matches.read','predictions.read','value.read',
                                          'favorites.write','simulation.write','notifications.manage'))
   OR (r.code = 'analyst' AND p.code IN ('matches.read','predictions.read','value.read',
                                          'favorites.write','simulation.write','notifications.manage',
                                          'admin.models','admin.audit'))
   OR (r.code = 'admin')
   OR (r.code = 'service' AND p.code IN ('matches.read','predictions.read','value.read'));

INSERT INTO value_thresholds
  (market_code, min_ev, min_ev_lower, max_margin, min_data_quality, min_odds, max_odds, max_age_seconds)
VALUES
  ('1X2',          0.0300, 0.0050, 0.060, 0.700,  1.30,  8.00, 120),
  ('DC',           0.0250, 0.0050, 0.050, 0.720,  1.10,  3.50, 120),
  ('DNB',          0.0300, 0.0050, 0.050, 0.720,  1.20,  5.00, 120),
  ('OU',           0.0300, 0.0050, 0.055, 0.700,  1.40,  4.00, 120),
  ('BTTS',         0.0350, 0.0075, 0.055, 0.700,  1.40,  3.50, 120),
  ('AH',           0.0350, 0.0075, 0.040, 0.720,  1.50,  3.50, 120),
  ('CS',           0.0600, 0.0150, 0.100, 0.800,  5.00, 25.00, 180),
  ('HT_1X2',       0.0500, 0.0100, 0.070, 0.750,  1.50,  8.00, 180),
  ('HT_OU',        0.0500, 0.0100, 0.070, 0.750,  1.50,  4.00, 180),
  ('CORNERS_OU',   0.0500, 0.0100, 0.070, 0.750,  1.50,  4.00, 180),
  ('CARDS_OU',     0.0500, 0.0100, 0.070, 0.750,  1.50,  4.00, 180),
  ('PLAYER_GOALS', 0.0600, 0.0150, 0.090, 0.800,  1.50, 15.00, 300);

INSERT INTO system_settings (key, value, description) VALUES
  ('value_engine', '{"enabled":true,"min_priority_visible":"C","max_opportunities_per_match":5,"no_bet_when_no_gate":true}'::jsonb,
   'Paramètres du moteur de value'),
  ('data_freshness', '{"prematch_seconds":120,"live_seconds":30,"stale_badge_seconds":600}'::jsonb,
   'Fraîcheur des cotes'),
  ('simulation', '{"default_kelly_fraction":0.25,"max_stake_pct":0.01,"max_daily_pct":0.05,"martingale":false}'::jsonb,
   'Simulation de bankroll'),
  ('legal', '{"min_age":18,"disclaimer_required":true,"automatic_betting":false}'::jsonb,
   'Contraintes légales et produit');
