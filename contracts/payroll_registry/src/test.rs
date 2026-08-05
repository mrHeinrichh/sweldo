extern crate std;

use super::*;
use soroban_sdk::testutils::{Address as _, BytesN as _};

#[test]
fn records_and_reads_payroll_schedule() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register(PayrollRegistry, ());
    let client = PayrollRegistryClient::new(&env, &contract_id);

    let id = BytesN::<32>::random(&env);
    let employer = Address::generate(&env);
    let worker = Address::generate(&env);
    let payout_tx_hash = BytesN::<32>::random(&env);
    let asset_code = String::from_str(&env, "XLM");
    let claimable_balance_id = String::from_str(
        &env,
        "00000000d158ad30cb62bb00566b5063d58ef9f82f8d65fb40a04dc340ee8df8f050caeb",
    );

    let result = client.record_schedule(
        &id,
        &employer,
        &worker,
        &1_000_000,
        &asset_code,
        &60,
        &claimable_balance_id,
        &payout_tx_hash,
    );

    assert_eq!(result, id.clone());
    assert_eq!(client.count(), 1);
    assert_eq!(client.get_schedule_id(&0), Some(id.clone()));

    let schedule = client.get_schedule(&id).unwrap();
    assert_eq!(schedule.employer, employer);
    assert_eq!(schedule.worker, worker);
    assert_eq!(schedule.amount, 1_000_000);
    assert_eq!(schedule.asset_code, asset_code);
    assert_eq!(schedule.cadence_seconds, 60);
    assert_eq!(schedule.claimable_balance_id, claimable_balance_id);
    assert_eq!(schedule.payout_tx_hash, payout_tx_hash);
}

#[test]
fn rejects_duplicate_schedule_ids() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register(PayrollRegistry, ());
    let client = PayrollRegistryClient::new(&env, &contract_id);

    let id = BytesN::<32>::random(&env);
    let employer = Address::generate(&env);
    let worker = Address::generate(&env);
    let payout_tx_hash = BytesN::<32>::random(&env);
    let asset_code = String::from_str(&env, "XLM");
    let claimable_balance_id = String::from_str(&env, "claimable-balance-proof");

    let first = client.record_schedule(
        &id,
        &employer,
        &worker,
        &1,
        &asset_code,
        &60,
        &claimable_balance_id,
        &payout_tx_hash,
    );
    let second = client.try_record_schedule(
        &id,
        &employer,
        &worker,
        &1,
        &asset_code,
        &60,
        &claimable_balance_id,
        &payout_tx_hash,
    );

    assert_eq!(first, id);
    assert_eq!(second, Err(Ok(RegistryError::ScheduleAlreadyExists)));
}
