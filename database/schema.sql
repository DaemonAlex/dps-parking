--[[
    DPS-Parking - Database Schema
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Run this SQL to add required columns for vehicle state persistence.
    Uses JSON columns for efficient single-query fetches.
]]

-- Add parking columns to player_vehicles (QBCore) / owned_vehicles (ESX)
-- Run the appropriate version for your framework:

-- ==========================================
-- QBCore: player_vehicles table
-- ==========================================

ALTER TABLE `player_vehicles`
    ADD COLUMN IF NOT EXISTS `parking_data` JSON DEFAULT NULL COMMENT 'DPS-Parking: location, street, steerangle',
    ADD COLUMN IF NOT EXISTS `vehicle_state` JSON DEFAULT NULL COMMENT 'DPS-Parking: damage, fuel, extras, neon',
    ADD COLUMN IF NOT EXISTS `parking_lot` VARCHAR(50) DEFAULT NULL COMMENT 'DPS-Parking: lot ID if in managed lot',
    ADD COLUMN IF NOT EXISTS `parked_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'DPS-Parking: when vehicle was parked';

-- Index for efficient parked vehicle queries
CREATE INDEX IF NOT EXISTS `idx_parking_state` ON `player_vehicles` (`state`, `parked_at`);
CREATE INDEX IF NOT EXISTS `idx_parking_lot` ON `player_vehicles` (`parking_lot`);

-- ==========================================
-- ESX: owned_vehicles table
-- ==========================================

ALTER TABLE `owned_vehicles`
    ADD COLUMN IF NOT EXISTS `parking_data` JSON DEFAULT NULL COMMENT 'DPS-Parking: location, street, steerangle',
    ADD COLUMN IF NOT EXISTS `vehicle_state` JSON DEFAULT NULL COMMENT 'DPS-Parking: damage, fuel, extras, neon',
    ADD COLUMN IF NOT EXISTS `parking_lot` VARCHAR(50) DEFAULT NULL COMMENT 'DPS-Parking: lot ID if in managed lot',
    ADD COLUMN IF NOT EXISTS `parked_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'DPS-Parking: when vehicle was parked';

-- Index for efficient parked vehicle queries
CREATE INDEX IF NOT EXISTS `idx_parking_stored` ON `owned_vehicles` (`stored`, `parked_at`);
CREATE INDEX IF NOT EXISTS `idx_parking_lot` ON `owned_vehicles` (`parking_lot`);

-- ==========================================
-- DPS-Parking: VIP Players table
-- ==========================================

CREATE TABLE IF NOT EXISTS `dps_parking_vip` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `slots` INT DEFAULT 10,
    `perks` JSON DEFAULT NULL COMMENT 'Additional VIP perks',
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_vip_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- DPS-Parking: Business Ownership table
-- ==========================================

CREATE TABLE IF NOT EXISTS `dps_parking_business` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `lot_id` VARCHAR(50) NOT NULL UNIQUE,
    `citizenid` VARCHAR(50) NOT NULL,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `revenue` INT DEFAULT 0,
    `employees` JSON DEFAULT NULL COMMENT 'Array of employee citizenids',
    `upgrades` JSON DEFAULT NULL COMMENT 'Purchased upgrades',
    `settings` JSON DEFAULT NULL COMMENT 'Owner customizations',
    INDEX `idx_business_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- DPS-Parking: Meter Sessions table
-- ==========================================

CREATE TABLE IF NOT EXISTS `dps_parking_meters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(10) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `zone` VARCHAR(50) DEFAULT NULL,
    `paid_amount` INT DEFAULT 0,
    `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    `status` ENUM('active', 'expired', 'cancelled') DEFAULT 'active',
    INDEX `idx_meter_plate` (`plate`),
    INDEX `idx_meter_expires` (`expires_at`),
    INDEX `idx_meter_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- DPS-Parking: Delivery History table
-- ==========================================

CREATE TABLE IF NOT EXISTS `dps_parking_deliveries` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `delivery_id` VARCHAR(50) NOT NULL UNIQUE,
    `citizenid` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(10) NOT NULL,
    `from_location` JSON NOT NULL COMMENT 'Pickup coordinates',
    `to_location` JSON NOT NULL COMMENT 'Delivery coordinates',
    `fee` INT DEFAULT 0,
    `status` ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_delivery_citizen` (`citizenid`),
    INDEX `idx_delivery_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- DPS-Parking: Audit Log table
-- ==========================================

CREATE TABLE IF NOT EXISTS `dps_parking_audit` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `action` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `plate` VARCHAR(10) DEFAULT NULL,
    `details` JSON DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_audit_action` (`action`),
    INDEX `idx_audit_citizen` (`citizenid`),
    INDEX `idx_audit_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
