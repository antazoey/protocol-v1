import pytest
import datetime as dt
import brownie
import time

from brownie.network import chain
from decimal import Decimal
from web3 import Web3


MAX_NUMBER_OF_LOANS = 10
MATURITY = int(dt.datetime.now().timestamp()) + 30 * 24 * 60 * 60
LOAN_AMOUNT = Web3.toWei(0.1, "ether")
LOAN_INTEREST = 250  # 2.5% in parts per 10000


@pytest.fixture
def contract_owner(accounts):
    yield accounts[0]


@pytest.fixture
def borrower(accounts):
    yield accounts[1]


@pytest.fixture
def investor(accounts):
    yield accounts[2]


@pytest.fixture
def loans_contract(accounts):
    yield accounts[3]



@pytest.fixture
def erc20_contract(ERC20PresetMinterPauser, contract_owner):
    yield ERC20PresetMinterPauser.deploy("Wrapped ETH", "WETH", {'from': contract_owner})


@pytest.fixture
def erc721_contract(ERC721PresetMinterPauserAutoId, contract_owner):
    yield ERC721PresetMinterPauserAutoId.deploy(
        "VeeFriends",
        "VEE",
        "tokenURI",
        {'from': contract_owner}
    )


@pytest.fixture
def test_collaterals(erc721_contract):
    result = []
    for k in range(5):
        result.append((erc721_contract.address, k))
    yield result


@pytest.fixture
def loans_core_contract(LoansCore, loans_contract, contract_owner):
    yield LoansCore.deploy(loans_contract.address, MAX_NUMBER_OF_LOANS, {"from": contract_owner})


def test_initial_state(loans_core_contract, loans_contract, contract_owner):
    # Check if the constructor of the contract is set up properly
    assert loans_core_contract.owner() == contract_owner
    assert loans_core_contract.loansPeripheral() == loans_contract
    assert loans_core_contract.maxAllowedLoans() == MAX_NUMBER_OF_LOANS


def test_change_ownership_wrong_sender(loans_core_contract, borrower):
    with brownie.reverts("Only the owner can change the contract ownership"):
        loans_core_contract.changeOwnership(borrower, {"from": borrower})


def test_change_ownership_same_owner(loans_core_contract, contract_owner):
    with brownie.reverts("The new owner should be different than the current owner"):
        loans_core_contract.changeOwnership(contract_owner, {"from": contract_owner})


def test_change_ownership(loans_core_contract, borrower, contract_owner):
    loans_core_contract.changeOwnership(borrower, {"from": contract_owner})
    assert loans_core_contract.owner() == borrower

    loans_core_contract.changeOwnership(contract_owner, {"from": borrower})
    assert loans_core_contract.owner() == contract_owner


def test_change_loans_peripheral_wrong_sender(loans_core_contract, loans_contract, borrower):
    with brownie.reverts("Only the owner can change the contract ownership"):
        loans_core_contract.changeLoansPeripheral(loans_contract, {"from": borrower})


def test_change_loans_peripheral_same_address(loans_core_contract, loans_contract, contract_owner):
    with brownie.reverts("The new loans peripheral address should be different than the current one"):
        loans_core_contract.changeLoansPeripheral(loans_contract, {"from": contract_owner})


def test_change_loans_peripheral(loans_core_contract, loans_contract, contract_owner):
    loans_core_contract.changeLoansPeripheral(contract_owner, {"from": contract_owner})
    assert loans_core_contract.loansPeripheral() == contract_owner

    loans_core_contract.changeLoansPeripheral(loans_contract, {"from": contract_owner})
    assert loans_core_contract.loansPeripheral() == loans_contract


def test_add_loan_wrong_sender(loans_core_contract, contract_owner, borrower, test_collaterals):
    with brownie.reverts("Only defined loans peripheral can add loans"):
        loans_core_contract.addLoan(
            borrower,
            LOAN_AMOUNT,
            LOAN_INTEREST,
            MATURITY,
            test_collaterals,
            {"from": contract_owner}
        )


def test_add_loan(loans_core_contract, loans_contract, borrower, test_collaterals):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value
    assert loan_id == 0
    assert loans_core_contract.nextLoanId(borrower) == 1
    
    assert len(loans_core_contract.getPendingBorrowerLoans(borrower)) == 1
    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 0

    assert loans_core_contract.getLoanAmount(borrower, loan_id) == LOAN_AMOUNT
    assert loans_core_contract.getLoanInterest(borrower, loan_id) == LOAN_INTEREST
    assert loans_core_contract.getLoanMaturity(borrower, loan_id) == MATURITY
    assert loans_core_contract.getLoanPaidAmount(borrower, loan_id) == 0
    assert not loans_core_contract.getLoanStarted(borrower, loan_id)
    assert len(loans_core_contract.getLoanCollaterals(borrower, loan_id)) == len(test_collaterals)
    assert loans_core_contract.getLoanCollaterals(borrower, loan_id) == test_collaterals

    assert loans_core_contract.getLoanIdsUsedByAddress(borrower)[0]
    assert not any(loans_core_contract.getLoanIdsUsedByAddress(borrower)[1:])


def test_add_loan_max_loans_reached(loans_core_contract, loans_contract, erc721_contract, borrower):
    for k in range(MAX_NUMBER_OF_LOANS):
        loans_core_contract.addLoan(
            borrower,
            LOAN_AMOUNT,
            LOAN_INTEREST,
            MATURITY,
            [(erc721_contract, k)],
            {"from": loans_contract}
        )
        time.sleep(0.2)

    with brownie.reverts("Max number of loans for borrower already reached"):
        loans_core_contract.addLoan(
            borrower,
            LOAN_AMOUNT,
            LOAN_INTEREST,
            MATURITY,
            [(erc721_contract, 10)],
            {"from": loans_contract}
        )


def test_remove_loan_wrong_sender(loans_core_contract, contract_owner, borrower):
    with brownie.reverts("Only defined loans peripheral can remove loans"):
        loans_core_contract.removeLoan(borrower, 0, {"from": contract_owner})


def test_remove_loan_no_loan(loans_core_contract, loans_contract, borrower):
    with brownie.reverts("No loan created for borrower with passed id"):
        loans_core_contract.removeLoan(borrower, 0, {"from": loans_contract})


def test_remove_loan(loans_core_contract, loans_contract, borrower, test_collaterals):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.removeLoan(borrower, loan_id, {"from": loans_contract})

    assert loans_core_contract.nextLoanId(borrower) == 0
    assert len(loans_core_contract.getPendingBorrowerLoans(borrower)) == 0
    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 0

    assert not any(loans_core_contract.getLoanIdsUsedByAddress(borrower))


def test_update_loan_started_wrong_sender(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    with brownie.reverts("Only defined loans peripheral can update loans"):
        loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": contract_owner})


def test_update_loan_started_no_loan(
    loans_core_contract,
    loans_contract,
    borrower
):
    with brownie.reverts("No loan created for borrower with passed id"):
        loans_core_contract.updateLoanStarted(borrower, 0, {"from": loans_contract})


def test_update_loan_started(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    assert len(loans_core_contract.getPendingBorrowerLoans(borrower)) == 0
    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 1

    assert loans_core_contract.getLoanAmount(borrower, loan_id) == LOAN_AMOUNT
    assert loans_core_contract.getLoanInterest(borrower, loan_id) == LOAN_INTEREST
    assert loans_core_contract.getLoanMaturity(borrower, loan_id) == MATURITY
    assert loans_core_contract.getLoanPaidAmount(borrower, loan_id) == 0
    assert loans_core_contract.getLoanStarted(borrower, loan_id)
    assert len(loans_core_contract.getLoanCollaterals(borrower, loan_id)) == len(test_collaterals)
    assert loans_core_contract.getLoanCollaterals(borrower, loan_id) == test_collaterals

    assert loans_core_contract.getLoanIdsUsedByAddress(borrower)[0]
    assert not any(loans_core_contract.getLoanIdsUsedByAddress(borrower)[1:])


def test_update_loan_started_already_started(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    with brownie.reverts("Loan already started"):
        loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})


def test_update_paid_amount_wrong_sender(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    with brownie.reverts("Only defined loans peripheral can update loans"):
        loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT, {"from": contract_owner})


def test_update_paid_amount_no_loan(
    loans_core_contract,
    loans_contract,
    borrower
):
    with brownie.reverts("No loan created for borrower with passed id"):
        loans_core_contract.updateLoanPaidAmount(borrower, 0, LOAN_AMOUNT, {"from": loans_contract})


def test_update_paid_amount_no_loan(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    with brownie.reverts("The loan has not been started yet"):
        loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT, {"from": loans_contract})


def test_update_paid_amount_more_than_needed(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    with brownie.reverts("The amount paid is higher than the amount left to be paid"):
        loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT * 2, {"from": loans_contract})


def test_update_paid_amount(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT, {"from": loans_contract})

    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 1
    assert loans_core_contract.getLoanPaidAmount(borrower, loan_id) == LOAN_AMOUNT


def test_update_paid_amount_multiple(
    loans_core_contract,
    loans_contract,
    contract_owner,
    borrower,
    test_collaterals
):
    tx_add_loan = loans_core_contract.addLoan(
        borrower,
        LOAN_AMOUNT,
        LOAN_INTEREST,
        MATURITY,
        test_collaterals,
        {"from": loans_contract}
    )

    loan_id = tx_add_loan.return_value

    loans_core_contract.updateLoanStarted(borrower, loan_id, {"from": loans_contract})

    loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT / 2.0, {"from": loans_contract})

    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 1
    assert loans_core_contract.getLoanPaidAmount(borrower, loan_id) == LOAN_AMOUNT / 2.0

    loans_core_contract.updateLoanPaidAmount(borrower, loan_id, LOAN_AMOUNT / 2.0, {"from": loans_contract})

    assert len(loans_core_contract.getBorrowerLoans(borrower)) == 1
    assert loans_core_contract.getLoanPaidAmount(borrower, loan_id) == LOAN_AMOUNT
