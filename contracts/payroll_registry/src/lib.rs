#![no_std]

use soroban_sdk::{contract, contracterror, contractimpl, contracttype, symbol_short, Address, BytesN, Env, String};

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PayrollSchedule {
    pub id: BytesN<32>,
    pub employer: Address,
    pub worker: Address,
    pub amount: i128,
    pub asset_code: String,
    pub cadence_seconds: u64,
    pub claimable_balance_id: String,
    pub payout_tx_hash: BytesN<32>,
    pub created_ledger: u32,
}

#[contracttype]
pub enum DataKey {
    Schedule(BytesN<32>),
    ScheduleByIndex(u32),
    ScheduleCount,
}

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum RegistryError {
    ScheduleAlreadyExists = 1,
    AmountMustBePositive = 2,
    MissingClaimableBalance = 3,
}

#[contract]
pub struct PayrollRegistry;

#[contractimpl]
impl PayrollRegistry {
    pub fn record_schedule(
        env: Env,
        id: BytesN<32>,
        employer: Address,
        worker: Address,
        amount: i128,
        asset_code: String,
        cadence_seconds: u64,
        claimable_balance_id: String,
        payout_tx_hash: BytesN<32>,
    ) -> Result<BytesN<32>, RegistryError> {
        employer.require_auth();

        if amount <= 0 {
            return Err(RegistryError::AmountMustBePositive);
        }
        if claimable_balance_id.len() == 0 {
            return Err(RegistryError::MissingClaimableBalance);
        }

        let key = DataKey::Schedule(id.clone());
        if env.storage().persistent().has(&key) {
            return Err(RegistryError::ScheduleAlreadyExists);
        }

        let schedule = PayrollSchedule {
            id: id.clone(),
            employer,
            worker,
            amount,
            asset_code,
            cadence_seconds,
            claimable_balance_id,
            payout_tx_hash,
            created_ledger: env.ledger().sequence(),
        };

        let count = Self::count(env.clone());
        env.storage().persistent().set(&key, &schedule);
        env.storage()
            .persistent()
            .set(&DataKey::ScheduleByIndex(count), &id);
        env.storage()
            .persistent()
            .set(&DataKey::ScheduleCount, &(count + 1));
        env.events()
            .publish((symbol_short!("schedule"), symbol_short!("recorded")), id.clone());

        Ok(id)
    }

    pub fn get_schedule(env: Env, id: BytesN<32>) -> Option<PayrollSchedule> {
        env.storage().persistent().get(&DataKey::Schedule(id))
    }

    pub fn get_schedule_id(env: Env, index: u32) -> Option<BytesN<32>> {
        env.storage().persistent().get(&DataKey::ScheduleByIndex(index))
    }

    pub fn count(env: Env) -> u32 {
        env.storage()
            .persistent()
            .get(&DataKey::ScheduleCount)
            .unwrap_or(0)
    }
}

#[cfg(test)]
mod test;
