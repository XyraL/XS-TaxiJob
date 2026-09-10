CREATE TABLE IF NOT EXISTS `xs_taxi_drivers` (
    `citizenid`      VARCHAR(64)   NOT NULL,
    `reputation`     INT UNSIGNED  NOT NULL DEFAULT 0,
    `total_fares`    INT UNSIGNED  NOT NULL DEFAULT 0,
    `total_earned`   INT UNSIGNED  NOT NULL DEFAULT 0,
    `total_distance` INT UNSIGNED  NOT NULL DEFAULT 0,
    `rating_sum`     DECIMAL(10,2) NOT NULL DEFAULT 0,
    `rating_count`   INT UNSIGNED  NOT NULL DEFAULT 0,
    `created_at`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `reputation` (`reputation`)
);

CREATE TABLE IF NOT EXISTS `xs_taxi_fares` (
    `id`             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `citizenid`      VARCHAR(64)   NOT NULL,
    `passenger`      VARCHAR(64)   DEFAULT NULL,
    `kind`           VARCHAR(8)    NOT NULL DEFAULT 'npc',
    `pickup_label`   VARCHAR(64)   NOT NULL,
    `dropoff_label`  VARCHAR(64)   NOT NULL,
    `distance`       INT UNSIGNED  NOT NULL DEFAULT 0,
    `duration`       INT UNSIGNED  NOT NULL DEFAULT 0,
    `fare`           INT UNSIGNED  NOT NULL DEFAULT 0,
    `tip`            INT UNSIGNED  NOT NULL DEFAULT 0,
    `rating`         DECIMAL(3,2)  NOT NULL DEFAULT 5.00,
    `created_at`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `driver` (`citizenid`, `id`),
    KEY `created` (`created_at`)
);

CREATE TABLE IF NOT EXISTS `xs_taxi_shifts` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(64)  NOT NULL,
    `vehicle`    VARCHAR(32)  DEFAULT NULL,
    `fares`      INT UNSIGNED NOT NULL DEFAULT 0,
    `earned`     INT UNSIGNED NOT NULL DEFAULT 0,
    `distance`   INT UNSIGNED NOT NULL DEFAULT 0,
    `started_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at`   TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `driver` (`citizenid`, `id`)
);
