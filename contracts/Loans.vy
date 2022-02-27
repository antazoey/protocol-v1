# @version ^0.3.2


# Interfaces

import interfaces.ILoans as LoansInterface

implements: LoansInterface

interface LendingPool:
  def sendFunds(_to: address, _amount: uint256) -> uint256: nonpayable
  def receiveFunds(_owner: address, _amount: uint256, _rewardsAmount: uint256) -> uint256: nonpayable
  def maxFundsInvestable() -> uint256: nonpayable
  def erc20TokenContract() -> address: nonpayable


interface CollateralContract:
  def supportsInterface(_interfaceID: bytes32) -> bool: view
  def ownerOf(tokenId: uint256) -> address: view
  def getApproved(tokenId: uint256) -> address: view
  def isApprovedForAll(owner: address, operator: address) -> bool: view
  def safeTransferFrom(_from: address, _to: address, tokenId: uint256): nonpayable
  def transferFrom(_from: address, _to: address, tokenId: uint256): nonpayable


interface ERC20Token:
  def allowance(_owner: address, _spender: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view


# Structs

struct Collateral:
  contractAddress: address
  tokenId: uint256


struct Loan:
  id: uint256
  amount: uint256
  interest: uint256 # parts per 10000, e.g. 2.5% is represented by 250 parts per 10000
  maturity: uint256
  startTime: uint256
  collaterals: DynArray[Collateral, 10]
  paidAmount: uint256
  started: bool


# Events

event LoanCreated:
  borrower: address
  loanId: uint256

event LoanStarted:
  borrower: address
  loanId: uint256

event LoanPaid:
  borrower: address
  loanId: uint256
  amount: uint256

event PendingLoanCanceled:
  borrower: address
  loanId: uint256

event LoanCanceled:
  borrower: address
  loanId: uint256


# Global variables

owner: public(address)
maxAllowedLoans: public(uint256)
maxAllowedLoanDuration: public(uint256)
bufferToCancelLoan: public(uint256)

minLoanAmount: public(uint256)
maxLoanAmount: public(uint256)

isAcceptingLoans: public(bool)
isDeprecated: public(bool)

createdLoans: HashMap[address, DynArray[Loan, 10]]
createdLoanIdsUsed: HashMap[address, bool[10]]
nextCreatedLoanId: public(HashMap[address, uint256])

loans: HashMap[address, DynArray[Loan, 10]]
loanIdsUsed: HashMap[address, bool[10]]
nextLoanId: public(HashMap[address, uint256])

# _abi_encoded(token_address, token_id) -> map(borrower_address, loan_id)
collateralsInLoans: public(HashMap[bytes32, HashMap[address, uint256]])
collateralsInLoansUsed: public(HashMap[bytes32, HashMap[address, HashMap[uint256, bool]]])
collateralKeys: DynArray[bytes32, 2**50]
collateralsUsed: public(HashMap[bytes32, bool])
collateralsData: public(HashMap[bytes32, Collateral])

whitelistedCollaterals: public(HashMap[address, address])

lendingPool: LendingPool
lendingPoolAddress: public(address)

# Stats
currentStartedLoans: public(uint256)
totalStartedLoans: public(uint256)

totalPaidLoans: public(uint256)

totalDefaultedLoans: public(uint256)
totalDefaultedLoansAmount: public(uint256)

totalCanceledLoans: public(uint256)

highestSingleCollateralLoan: public(Loan)
highestCollateralBundleLoan: public(Loan)
highestRepayment: public(Loan)
highestDefaultedLoan: public(Loan)


@external
def __init__(
  _maxAllowedLoans: uint256,
  _maxAllowedLoanDuration: uint256,
  _bufferToCancelLoan: uint256,
  _minLoanAmount: uint256,
  _maxLoanAmount: uint256
):
  self.owner = msg.sender
  self.maxAllowedLoans = _maxAllowedLoans
  self.maxAllowedLoanDuration = _maxAllowedLoanDuration
  self.bufferToCancelLoan = _bufferToCancelLoan
  self.minLoanAmount = _minLoanAmount
  self.maxLoanAmount = _maxLoanAmount
  self.isAcceptingLoans = True
  self.isDeprecated = False


@view
@internal
def _borrowerLoans(_borrower: address) -> DynArray[Loan, 10]:
  return self.loans[_borrower]


@internal
def _areCollateralsWhitelisted(_collaterals: DynArray[Collateral, 10]) -> bool:
  for collateral in _collaterals:
    if self.whitelistedCollaterals[collateral.contractAddress] == empty(address):
      return False
  return True


@internal
def _areCollateralsOwned(_borrower: address, _collaterals: DynArray[Collateral, 10]) -> bool:
  for collateral in _collaterals:
    if CollateralContract(collateral.contractAddress).ownerOf(collateral.tokenId) != _borrower:
      return False
  return True


@view
@internal
def _checkNextCreatedLoanId(_borrower: address) -> uint256:
  for index in range(10):
    if not self.createdLoanIdsUsed[_borrower][index]:
      return index
  return self.maxAllowedLoans


@view
@internal
def _checkNextLoanId(_borrower: address) -> uint256:
  for index in range(10):
    if not self.loanIdsUsed[_borrower][index]:
      return index
  return self.maxAllowedLoans


@view
@internal
def _hasCreatedLoan(_borrower: address, _loanId: uint256) -> bool:
  if self.createdLoanIdsUsed[_borrower][_loanId]:
    return True
  return False


@view
@internal
def _hasStartedLoan(_borrower: address, _loanId: uint256) -> bool:
  if self.loanIdsUsed[_borrower][_loanId]:
    return self._borrowerLoans(_borrower)[_loanId].started
  return False


@view
@internal
def _checkHasBufferNotPassed(_blockTimestamp: uint256, _loanStartTime: uint256) -> bool:
  if _loanStartTime == 0:
    return False
  return _blockTimestamp - _loanStartTime < self.bufferToCancelLoan


@view
@internal
def _isCollateralApproved(_borrower: address, _operator: address, _contractAddress: address) -> bool:
  return CollateralContract(_contractAddress).isApprovedForAll(_borrower, _operator)


@view
@internal
def _areCollateralsApproved(_borrower: address, _collaterals: DynArray[Collateral, 10]) -> bool:
  for collateral in _collaterals:
    if not self._isCollateralApproved(_borrower, self, collateral.contractAddress):
      return False
  return True


@view
@internal
def _computeCollateralKey(_collateralAddress: address, _collateralId: uint256) -> bytes32:
  return keccak256(_abi_encode(_collateralAddress, convert(_collateralId, bytes32)))


@internal
def _addCreatedLoan(_borrower: address, _loan: Loan):
  if len(self.createdLoans[_borrower]) == self.nextCreatedLoanId[_borrower]:
    self.createdLoans[_borrower].append(_loan)
  elif len(self.createdLoans[_borrower]) >= self.nextCreatedLoanId[_borrower] + 1:
    self.createdLoans[_borrower][self.nextCreatedLoanId[_borrower]] = _loan
  self.createdLoanIdsUsed[_borrower][self.nextCreatedLoanId[_borrower]] = True
  self.nextCreatedLoanId[_borrower] = self._checkNextCreatedLoanId(_borrower)


@internal
def _removeCreatedLoan(_borrower: address, _loanId: uint256):
  if self.createdLoanIdsUsed[_borrower][_loanId]:
    self.createdLoans[_borrower][_loanId] = empty(Loan)
    self.nextCreatedLoanId[_borrower] = _loanId
    self.createdLoanIdsUsed[_borrower][_loanId] = False


@internal
def _addLoan(_borrower: address, _loan: Loan):
  if len(self.loans[_borrower]) == self.nextLoanId[_borrower]:
    self.loans[_borrower].append(_loan)
  elif len(self.loans[_borrower]) >= self.nextLoanId[_borrower] + 1:
    self.loans[_borrower][self.nextLoanId[_borrower]] = _loan
  self.loanIdsUsed[_borrower][self.nextLoanId[_borrower]] = True
  self.nextLoanId[_borrower] = self._checkNextLoanId(_borrower)


@internal
def _removeLoan(_borrower: address, _loanId: uint256):
  if self.loanIdsUsed[_borrower][_loanId]:
    self.loans[_borrower][_loanId] = empty(Loan)
    self.nextLoanId[_borrower] = _loanId
    self.loanIdsUsed[_borrower][_loanId] = False


@internal
def _updateLoanPaidAmount(_borrower: address, _loanId: uint256, _paidAmount: uint256):
  if self.loanIdsUsed[_borrower][_loanId]:
    self.loans[_borrower][_loanId].paidAmount += _paidAmount


@internal
def _addCollateralToLoan(_borrower: address, _collateral: Collateral, _loanId: uint256):
  key: bytes32 = self._computeCollateralKey(_collateral.contractAddress, _collateral.tokenId)
  self.collateralsInLoans[key][_borrower] = _loanId
  self.collateralsInLoansUsed[key][_borrower][_loanId] = True


@internal
def _removeCollateralFromLoan(_borrower: address, _collateral: Collateral, _loanId: uint256):
  key: bytes32 = self._computeCollateralKey(_collateral.contractAddress, _collateral.tokenId)
  self.collateralsInLoansUsed[key][_borrower][_loanId] = False


@internal
def _updateCollaterals(_collateral: Collateral, _toRemove: bool):
  key: bytes32 = self._computeCollateralKey(_collateral.contractAddress, _collateral.tokenId)

  if key not in self.collateralKeys and not _toRemove:
    self.collateralKeys.append(key)
    self.collateralsUsed[key] = True
    self.collateralsData[key] = _collateral
  elif key in self.collateralKeys:
    self.collateralsUsed[key] = not _toRemove


@external
def changeOwnership(_newOwner: address) -> address:
  assert msg.sender == self.owner, "Only the owner can change the contract ownership"

  self.owner = _newOwner

  return self.owner


@external
def changeMaxAllowedLoans(_maxAllowedLoans: uint256) -> uint256:
  assert msg.sender == self.owner, "Only the owner can change the max allowed loans per address"

  self.maxAllowedLoans = _maxAllowedLoans

  return self.maxAllowedLoans


@external
def changeMaxAllowedLoanDuration(_maxAllowedLoanDuration: uint256) -> uint256:
  assert msg.sender == self.owner, "Only the owner can change the max allowed loan duration"

  self.maxAllowedLoanDuration = _maxAllowedLoanDuration

  return self.maxAllowedLoanDuration


@external
def addCollateralToWhitelist(_address: address) -> bool:
  assert msg.sender == self.owner, "Only the contract owner can add collateral addresses to the whitelist"
  assert _address.is_contract == True, "The _address sent does not have a contract deployed"

  self.whitelistedCollaterals[_address] = _address

  return True


@external
def removeCollateralFromWhitelist(_address: address) -> bool:
  assert msg.sender == self.owner, "Only the contract owner can add collateral addresses to the whitelist"

  self.whitelistedCollaterals[_address] = empty(address)

  return True


@external
def changeMinLoanAmount(_newMinLoanAmount: uint256) -> uint256:
  assert msg.sender == self.owner, "Only the contract owner can change the min loan amount"
  assert _newMinLoanAmount <= self.maxLoanAmount, "The min loan amount can not be higher than the max loan amount"

  self.minLoanAmount = _newMinLoanAmount

  return self.minLoanAmount


@external
def changeMaxLoanAmount(_newMaxLoanAmount: uint256) -> uint256:
  assert msg.sender == self.owner, "Only the contract owner can change the max loan amount"
  assert _newMaxLoanAmount >= self.minLoanAmount, "The max loan amount can not be lower than the min loan amount"

  self.maxLoanAmount = _newMaxLoanAmount

  return self.maxLoanAmount


@external
def setLendingPoolAddress(_address: address) -> address:
  assert msg.sender == self.owner, "Only the contract owner can set the investment pool address"

  self.lendingPool = LendingPool(_address)
  self.lendingPoolAddress = _address
  return self.lendingPoolAddress


@external
def changeContractStatus(_flag: bool) -> bool:
  assert msg.sender == self.owner, "Only the contract owner can change the status of the contract"
  assert self.isAcceptingLoans != _flag, "The new contract status should be different than the current status"

  self.isAcceptingLoans = _flag

  return self.isAcceptingLoans


@external
def deprecate() -> bool:
  assert msg.sender == self.owner, "Only the contract owner can deprecate the contract"
  assert not self.isDeprecated, "The contract is already deprecated"
  
  self.isDeprecated = True
  self.isAcceptingLoans = False

  return self.isDeprecated


@view
@external
def createdLoanIdsUsedByAddress(_borrower: address) -> bool[10]:
  return self.createdLoanIdsUsed[_borrower]


@view
@external
def loanIdsUsedByAddress(_borrower: address) -> bool[10]:
  return self.loanIdsUsed[_borrower]


@view
@external
def borrowerLoan(_borrower: address, _loanId: uint256) -> Loan:
  if _loanId >= self.maxAllowedLoans:
    return empty(Loan)
  elif _loanId < len(self.loans[_borrower]) and self.loanIdsUsed[_borrower][_loanId]:
    return self.loans[_borrower][_loanId]
  return empty(Loan)


@view
@external
def borrowerLoans(_borrower: address) -> DynArray[Loan, 10]:
  result: DynArray[Loan, 10] = []
  _loans: DynArray[Loan, 10] = self.loans[_borrower]
  for loan in _loans:
    if loan.amount > 0:
      result.append(loan)
  return result


@view
@external
def pendingBorrowerLoans(_borrower: address) -> DynArray[Loan, 10]:
  result: DynArray[Loan, 10] = []
  _createdLoans: DynArray[Loan, 10] = self.createdLoans[_borrower]
  for loan in _createdLoans:
    if loan.amount > 0:
      result.append(loan)
  return result


@view
@external
def getCreatedLoanIdsUsed(_borrower: address) -> bool[10]:
  return self.createdLoanIdsUsed[_borrower]


@view
@external
def getLoanIdsUsed(_borrower: address) -> bool[10]:
  return self.loanIdsUsed[_borrower]


@view
@external
def collateralKeysArray() -> DynArray[bytes32, 2**50]:
  return self.collateralKeys


@external
def reserve(
  _borrower: address,
  _amount: uint256,
  _interest: uint256,
  _maturity: uint256,
  _collaterals: DynArray[Collateral, 10]
) -> Loan:
  assert msg.sender == self.owner, "Only the contract owner can create loans"
  assert not self.isDeprecated, "The contract is deprecated, no more loans can be created"
  assert self.isAcceptingLoans, "The contract is not accepting more loans right now"
  assert block.timestamp <= _maturity, "Maturity can not be in the past"
  assert _maturity - block.timestamp <= self.maxAllowedLoanDuration, "Maturity can not exceed the max allowed"
  assert self.nextCreatedLoanId[_borrower] < self.maxAllowedLoans, "Max number of created loans already reached"
  assert self.nextLoanId[_borrower] < self.maxAllowedLoans, "Max number of started loans already reached"
  assert self._areCollateralsWhitelisted(_collaterals), "Not all collaterals are whitelisted"
  assert self._areCollateralsOwned(_borrower, _collaterals), "Not all collaterals are owned by the borrower"
  assert self._areCollateralsApproved(_borrower, _collaterals) == True, "Not all collaterals are approved to be transferred"
  assert self.lendingPool.maxFundsInvestable() >= _amount, "Insufficient funds in the lending pool"
  assert _amount >= self.minLoanAmount, "Loan amount is less than the min loan amount"
  assert _amount <= self.maxLoanAmount, "Loan amount is more than the max loan amount"


  newLoan: Loan = Loan(
    {
      id: self.nextCreatedLoanId[_borrower],
      amount: _amount,
      interest: _interest,
      maturity: _maturity,
      startTime: block.timestamp,
      paidAmount: 0,
      collaterals: _collaterals,
      started: False
    }
  )

  self._addCreatedLoan(_borrower, newLoan)

  log LoanCreated(_borrower, newLoan.id)

  return self.createdLoans[_borrower][newLoan.id]


@external
def start(
  _loanId: uint256
) -> Loan:
  assert not self.isDeprecated, "The contract is deprecated, please pay any outstanding loans"
  assert self.isAcceptingLoans, "The contract is not accepting more loans right now, please pay any outstanding loans"
  assert self._hasCreatedLoan(msg.sender, _loanId), "This loan has not been created for the sender"
  assert self.nextLoanId[msg.sender] < self.maxAllowedLoans, "Max number of loans already reached"

  loan: Loan = self.createdLoans[msg.sender][_loanId]
  assert self._areCollateralsWhitelisted(loan.collaterals), "Not all collaterals are whitelisted"
  assert self._areCollateralsOwned(msg.sender, loan.collaterals), "Not all collaterals are owned by the sender"
  assert self._areCollateralsApproved(msg.sender, loan.collaterals) == True, "Not all collaterals are approved to be transferred"
  assert self.lendingPool.maxFundsInvestable() >= loan.amount, "Insufficient funds in the lending pool"


  if block.timestamp > loan.maturity:
    self._removeCreatedLoan(msg.sender, _loanId)
    assert block.timestamp <= loan.maturity, "Maturity can not be in the past"


  loan.id = self.nextLoanId[msg.sender]
  loan.started = True
  self._removeCreatedLoan(msg.sender, _loanId)

  for collateral in loan.collaterals:
    self._addCollateralToLoan(msg.sender, collateral, loan.id)

    self._updateCollaterals(collateral, False)

    CollateralContract(collateral.contractAddress).transferFrom(
      msg.sender,
      self,
      collateral.tokenId
    )

  self._addLoan(msg.sender, loan)

  self.currentStartedLoans += 1
  self.totalStartedLoans += 1

  if len(loan.collaterals) == 1 and self.highestSingleCollateralLoan.amount < loan.amount:
    self.highestSingleCollateralLoan = loan
  elif len(loan.collaterals) > 1 and self.highestCollateralBundleLoan.amount < loan.amount:
    self.highestCollateralBundleLoan = loan
  
  self.lendingPool.sendFunds(msg.sender, loan.amount)

  log LoanStarted(msg.sender, loan.id)

  return self.loans[msg.sender][loan.id]


@external
def pay(_loanId: uint256, _amountPaid: uint256) -> Loan:
  assert self._hasStartedLoan(msg.sender, _loanId), "The sender has not started a loan with the given ID"

  loan: Loan = self.loans[msg.sender][_loanId]

  assert block.timestamp <= loan.maturity, "The maturity of the loan has already been reached and it defaulted"
  assert _amountPaid > 0, "The amount paid needs to be higher than 0"

  
  maxPayment: uint256 = loan.amount * (10000 + loan.interest) / 10000
  allowedPayment: uint256 = maxPayment - loan.paidAmount
  borrowerBalance: uint256 = ERC20Token(self.lendingPool.erc20TokenContract()).balanceOf(msg.sender)
  lendingPoolAllowance: uint256 = ERC20Token(self.lendingPool.erc20TokenContract()).allowance(msg.sender, self.lendingPoolAddress)
  assert _amountPaid <= allowedPayment, "The amount paid is higher than the amount left to be paid"
  assert borrowerBalance >= _amountPaid, "User has insufficient balance for the payment"
  assert lendingPoolAllowance >= _amountPaid, "User did not allow funds to be transferred"


  paidAmount: uint256 = _amountPaid * 10000 / (10000 + loan.interest)
  paidAmountInterest: uint256 = _amountPaid - paidAmount

  if _amountPaid == allowedPayment:
    for collateral in loan.collaterals:
      CollateralContract(collateral.contractAddress).safeTransferFrom(
        self,
        msg.sender,
        collateral.tokenId
      )

      self._removeCollateralFromLoan(msg.sender, collateral, _loanId)

      self._updateCollaterals(collateral, True)

    if self.highestRepayment.amount < loan.amount:
      self.highestRepayment = loan

    self._removeLoan(msg.sender, _loanId)

    self.currentStartedLoans -= 1
    self.totalPaidLoans += 1
  else:
    self._updateLoanPaidAmount(msg.sender, _loanId, paidAmount + paidAmountInterest)

    if self.highestRepayment.amount < loan.amount:
      self.highestRepayment = loan


  self.lendingPool.receiveFunds(msg.sender, paidAmount, paidAmountInterest)

  log LoanPaid(msg.sender, _loanId, _amountPaid)

  return self.loans[msg.sender][_loanId]


@external
def settleDefault(_borrower: address, _loanId: uint256) -> Loan:
  assert msg.sender == self.owner, "Only the contract owner can default loans"
  assert self._hasStartedLoan(_borrower, _loanId), "The _borrower has not started a loan with the given ID"


  loan: Loan = self.loans[_borrower][_loanId]

  assert block.timestamp > loan.maturity, "The maturity of the loan has not been reached yet"

  
  self.totalDefaultedLoansAmount += loan.amount

  for collateral in loan.collaterals:
    CollateralContract(collateral.contractAddress).safeTransferFrom(
      self,
      self.owner,
      collateral.tokenId
    )

    self._removeCollateralFromLoan(_borrower, collateral, _loanId)

    self._updateCollaterals(collateral, True)


  if self.highestDefaultedLoan.amount < loan.amount:
    self.highestDefaultedLoan = loan

  self._removeLoan(_borrower, _loanId)

  self.currentStartedLoans -= 1
  self.totalDefaultedLoans += 1

  return self.loans[_borrower][_loanId]


@external
def cancelPendingLoan(_loanId: uint256) -> Loan:
  assert self._hasCreatedLoan(msg.sender, _loanId), "The sender has not created a loan with the given ID"
  
  loan: Loan = self.createdLoans[msg.sender][_loanId]

  self._removeCreatedLoan(msg.sender, _loanId)

  log PendingLoanCanceled(msg.sender, _loanId)

  return self.createdLoans[msg.sender][_loanId]


@external
def cancelStartedLoan(_loanId: uint256) -> Loan:
  assert self._hasStartedLoan(msg.sender, _loanId), "The sender has not started a loan with the given ID"
  
  loan: Loan = self.loans[msg.sender][_loanId]

  assert self._checkHasBufferNotPassed(block.timestamp, loan.startTime), "The time buffer to cancel the loan has passed"


  for collateral in loan.collaterals:
    CollateralContract(collateral.contractAddress).safeTransferFrom(
      self,
      msg.sender,
      collateral.tokenId
    )

    self._removeCollateralFromLoan(msg.sender, collateral, _loanId)

    self._updateCollaterals(collateral, True)


  self.lendingPool.receiveFunds(msg.sender, loan.amount, 0)

  self._removeLoan(msg.sender, _loanId)

  self.currentStartedLoans -= 1
  self.totalCanceledLoans += 1

  log LoanCanceled(msg.sender, _loanId)

  return self.loans[msg.sender][_loanId]


@external
@payable
def __default__():
  if msg.value > 0:
    send(msg.sender, msg.value)
