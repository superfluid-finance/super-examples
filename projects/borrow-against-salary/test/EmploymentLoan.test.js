const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers , network} = require("hardhat")
const { assert } = require("chai")
const LoanArtifact = require("../artifacts/contracts/EmploymentLoan.sol/EmploymentLoan.json")
const { deployTestFramework } = require("@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework");
const TestToken = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json")


let contractsFramework;
let sfDeployer;
let sf
let dai
let daix
let admin
let borrower
let lender
let employer
let loanFactory
let employmentLoan

const alotOfEth = ethers.utils.parseEther("100000")

before(async function () {
    //get accounts from hardhat
    [admin, borrower, lender, employer] = await ethers.getSigners()
    
    sfDeployer = await deployTestFramework();
    // deploy the framework locally
    contractsFramework = await sfDeployer.frameworkDeployer.getFramework();

    // initialize framework
    sf = await Framework.create({
        chainId: 31337,
        provider: admin.provider,
        resolverAddress: contractsFramework.resolver, // (empty)
        protocolReleaseVersion: "test"
    });
    
    // DEPLOYING DAI and DAI wrapper super token (which will be our `spreaderToken`)
    tokenDeployment = await sfDeployer.superTokenDeployer.deployWrapperSuperToken(
        "Fake DAI Token",
        "fDAI",
        18,
        ethers.utils.parseEther("100000000000000000000000").toString()
    );

    daix = await sf.loadSuperToken("fDAIx");
    dai = new ethers.Contract(daix.underlyingToken.address, TestToken.abi, admin);

    const LoanFactory = await ethers.getContractFactory("LoanFactory", admin)
    loanFactory = await LoanFactory.deploy()

    await loanFactory.deployed()

    let borrowAmount = ethers.utils.parseEther("1000")
    let interest = 10
    let paybackMonths = 12

    await loanFactory.createNewLoan(
        borrowAmount, //borrowing 1000 fDAI tokens
        interest, // 10% annual interest
        paybackMonths, //in months
        employer.address, //address of employer
        borrower.address, //address of borrower
        daix.address,
        sf.settings.config.hostAddress
    )

    let loanAddress = await loanFactory.idToLoan(1)

    employmentLoan = new ethers.Contract(loanAddress, LoanArtifact.abi, admin)
})

beforeEach(async function () {
    await dai.mint(admin.address, alotOfEth)

    await dai.mint(employer.address, alotOfEth);
    await dai.mint(employer.address, alotOfEth);

    await dai.mint(lender.address, alotOfEth)

    await dai.approve(daix.address, alotOfEth)

    await dai.connect(employer).approve(daix.address, alotOfEth)

    await dai.connect(lender).approve(daix.address, alotOfEth)

    await daix.upgrade(alotOfEth)

    await daix.upgrade({amount: alotOfEth}).exec(employer);

    await daix.upgrade({amount: alotOfEth}).exec(lender);

    await daix.transfer({receiver: employmentLoan.address, amount: alotOfEth});
})

describe("employment loan deployment", async function () {
    it("0 deploys correctly", async function () {
        let borrowAmount = ethers.utils.parseEther("1000")
        let interest = 10
        let paybackMonths = 12

        let actualBorrowAmount = await employmentLoan.borrowAmount()
        let actualInterest = await employmentLoan.interestRate()
        let actualPaybackMonths = await employmentLoan.paybackMonths()
        let acutalEmployerAddress = await employmentLoan.employer()
        let actualBorrower = await employmentLoan.borrower()
        let actualBorrowToken = await employmentLoan.borrowToken()

        assert.equal(
            borrowAmount,
            actualBorrowAmount.toString(),
            "borrow amount not equal to intended amount"
        )

        assert.equal(
            interest,
            actualInterest,
            "interest rate not equal to intended rate"
        )

        assert.equal(
            paybackMonths,
            actualPaybackMonths,
            "payback months not equal to intended months"
        )

        assert.equal(
            employer.address,
            acutalEmployerAddress,
            "wrong employer address"
        )

        assert.equal(borrower.address, actualBorrower, "wrong borrower address")

        assert.equal(daix.address, actualBorrowToken, "wrong borrow token")
    })
})

describe("Loan is initialized properly", async function () {
    it("1 First flow into contract works correctly", async function () {
        let employerFlowOperation = daix.createFlow({
            receiver: employmentLoan.address,
            flowRate: "3215019290123456" // ~100k per year in usd
        })

        await employerFlowOperation.exec(employer)

        let employerNetFlowRate = await daix.getNetFlow({
            account: employer.address,
            providerOrSigner: employer
        })

        let borrowerNetFlowRate = await daix.getNetFlow({
            account: borrower.address,
            providerOrSigner: employer
        })

        let contractNetFlowRate = await daix.getNetFlow({
            account: employmentLoan.address,
            providerOrSigner: employer
        })

        assert.equal(employerNetFlowRate, -3215019290123456)

        assert.equal(borrowerNetFlowRate, 3215019290123456)

        assert.equal(contractNetFlowRate, 0)
    })

    it("2 - Flow Reduction works correctly", async function () {
        //testing reduction in flow

        const reduceFlowOperation = daix.updateFlow({
            receiver: employmentLoan.address,
            flowRate: "1000000"
        })

        await reduceFlowOperation.exec(employer)

        const newEmployerFlowRate = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: employer
        })

        const newBorrowerFlowRate = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const newContractFlowRate = await daix.getNetFlow({
            account: employmentLoan.address,
            providerOrSigner: employer
        })

        assert.equal(
            newEmployerFlowRate.flowRate,
            "1000000",
            "wrong employer flow rate"
        )

        assert.equal(
            newBorrowerFlowRate.flowRate,
            "1000000",
            "wrong borrower flow rate"
        )

        assert.equal(newContractFlowRate, 0, "contract is not balanced")
    })

    it("3 - should show that a loan is not closed (anyone can become a lender)", async function () {
        //before the lend function is called, both isClosed and loanOpen are false

        const loanOpen = await employmentLoan.loanOpen()
        assert.equal(loanOpen, false);

        const isClosed = await employmentLoan.isClosed()
        assert.equal(isClosed, false);
    })

    it("4 Lend Function works correctly", async function () {
        //should reduce flow rate, test to ensure failure, then test update flow rate
        //try calling lend - should revert

        const borrowAmount = await employmentLoan.borrowAmount()

        const daixApproval = daix.approve({receiver: employmentLoan.address, amount: borrowAmount});
        await daixApproval.exec(lender);

        const employerUpdateFlowOperation = daix.updateFlow({
            receiver: employmentLoan.address,
            flowRate: "3215019290123456"
        })

        await employerUpdateFlowOperation.exec(employer)

        let borrowerBalBefore = await daix.balanceOf({account: borrower.address, providerOrSigner: admin});

        let lenderBalBefore = await daix.balanceOf({account: lender.address, providerOrSigner: admin});

        let borrowerFlowRateBefore = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })


        //SENDING A SMALL AMOUNT OF FUNDS INTO CONTRACT FOR BUFFER
        await daix.transfer({receiver: employmentLoan.address, amount: ethers.utils.parseEther("100")}).exec(employer);

        await employmentLoan.connect(lender).lend()

        let lenderBalAfter = await daix.balanceOf({account: lender.address, providerOrSigner: admin});

        let borrowerBalAfter = await daix.balanceOf({account: borrower.address, providerOrSigner: admin});

        let borrowerFlowRateAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        let lenderFlowRateAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        let employerFlow = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: lender
        })

        let expectedLender = await employmentLoan.lender()
        let loanStartedTime = await employmentLoan.loanStartTime()

        let expectedFlowRate = await employmentLoan.getPaymentFlowRate()

        assert.isAtLeast(
            Number(borrowerBalBefore + borrowAmount),
            Number(borrowerBalAfter),
            "borrower bal did not increase enough"
        )

        assert.isAtMost(
            lenderBalBefore - borrowAmount,
            Number(lenderBalAfter),
            "lender should have less money"
        )

        assert.equal(
            Number(borrowerFlowRateAfter.flowRate),
            Number(
                Number(employerFlow.flowRate) -
                    Number(lenderFlowRateAfter.flowRate)
            ),
            "borrower flow rate incorrect"
            //borrower flow rate should decrease by paymentFlowrate amount after lend is called
        )

        assert.equal(
            //lender flow rate should increase by proper amount when lend is called
            Number(lenderFlowRateAfter.flowRate),
            Number(borrowerFlowRateBefore.flowRate) -
                (Number(borrowerFlowRateBefore.flowRate) - expectedFlowRate),
            "lender flowRate incorrect"
        )

        assert.equal(
            Number(lender.address),
            Number(expectedLender),
            "lender is not correct"
        )

        assert.notEqual(
            loanStartedTime,
            0,
            "loan has not been started properly"
        )
    })

    it("5 - flow is reduced", async function () {
        const updateFlowOp = await daix.updateFlow({
            receiver: employmentLoan.address,
            flowRate: "10000"
        })

        await updateFlowOp.exec(employer)

        const borrowFlowToLender = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const borrowerNewFlowRate = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        assert.equal(
            borrowFlowToLender.flowRate,
            "10000",
            "lender should be getting remainder"
        )
        //remaining amount should go to borrower
        assert.equal(
            borrowerNewFlowRate.flowRate,
            0,
            "borrower new flow should be zero"
        )
    })

    it("6 - should allow a loan to become solvent again after a flow is reduced", async function () {
        let employerFlowOperation = daix.updateFlow({
            receiver: employmentLoan.address,
            flowRate: "3215019290123456" // ~100k per year in usd
        })

        await employerFlowOperation.exec(employer)

        const employerFlowRate = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: lender
        })

        const borrowTokenFlowToLenderAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })
        //should be total inflow to contract from employer - flow to lender

        const borrowTokenFlowToBorrowerAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: lender
        })

        //should be total inflow to contract from employer - flow to lender

        assert.equal(
            Number(borrowTokenFlowToBorrowerAfter.flowRate),
            Number(
                Number(employerFlowRate.flowRate) -
                    Number(borrowTokenFlowToLenderAfter.flowRate)
            ),
            "borrower flow rate incorrect"
            //borrower flow rate should decrease by paymentFlowrate amount after lend is called
        )

        assert.equal(
            //lender flow rate should increase by proper amount when lend is called
            Number(borrowTokenFlowToLenderAfter.flowRate),
            Number(employerFlowRate.flowRate) -
                Number(borrowTokenFlowToBorrowerAfter.flowRate),
            "lender flowRate incorrect"
        )
    })

    it("7 - flow is deleted", async function () {
        //delete flow

        const deleteFlowOp = await daix.deleteFlow({
            sender: employer.address,
            receiver: employmentLoan.address
        })

        await deleteFlowOp.exec(employer)

        const newEmployerFlowRate = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: employer
        })

        const borrowFlowToLender = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const borrowerNewFlowRate = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        assert.equal(
            newEmployerFlowRate.flowRate,
            0,
            "employer to contract flow rate should be 0"
        )

        assert.equal(
            borrowFlowToLender.flowRate,
            0,
            "lender should no longer receive daix"
        )

        //remaining amount should go to borrower
        assert.equal(
            borrowerNewFlowRate.flowRate,
            "0",
            "borrower new flow should be zero"
        )
    })

    it("8 - should allow loan to become solvent again after deletion ", async function () {
        //re start flow

        let employerFlowOperation = daix.createFlow({
            receiver: employmentLoan.address,
            flowRate: "3215019290123456" // ~100k per year in usd
        })

        await employerFlowOperation.exec(employer)

        const employerFlowRate = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: lender
        })

        const borrowTokenFlowToLenderAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })
        //should be total inflow to contract from employer - flow to lender

        const borrowTokenFlowToBorrowerAfter = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: lender
        })

        //should be total inflow to contract from employer - flow to lender
        assert.equal(
            Number(borrowTokenFlowToBorrowerAfter.flowRate),
            Number(
                Number(employerFlowRate.flowRate) -
                    Number(borrowTokenFlowToLenderAfter.flowRate)
            ),
            "borrower flow rate incorrect"
            //borrower flow rate should decrease by paymentFlowrate amount after lend is called
        )
        assert.equal(
            //lender flow rate should increase by proper amount when lend is called
            Number(borrowTokenFlowToLenderAfter.flowRate),
            Number(employerFlowRate.flowRate) -
                Number(borrowTokenFlowToBorrowerAfter.flowRate),
            "lender flowRate incorrect"
        )
    })

    //todo fix - looks like transfer and approve opp don't work here
    it("9 closing the loan early with payment from borrower", async function () {
        //borrower sends payment to pay off loan
        const amountLeft = await employmentLoan
            .connect(borrower)
            .getTotalAmountRemaining()
        const lenderBalBefore = await daix.balanceOf({account: lender.address, providerOrSigner: admin})

        //somewhat impractical, but we'll assume that the borrower is sent money from lender (they just need the money in general to pay off loan)
        await daix.transfer({receiver: borrower.address, amount: amountLeft}).exec(lender);

        await daix.approve({receiver: employmentLoan.address, amount: amountLeft}).exec(borrower);

        await employmentLoan.connect(borrower).closeOpenLoan(amountLeft)

        const lenderFlowRateAfterCompletion = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const borrowerFlowRateAfterCompletion = await daix.getFlow({
            sender: employmentLoan.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const employerFlowRateAfterCompletion = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan.address,
            providerOrSigner: employer
        })

        const loanStatus = await employmentLoan.loanOpen()

        assert.equal(loanStatus, false)

        //This is exactly why there is a need for another variable besides @loanOpen - to differentiate between loans before and after being paid off.
        //It's impossible to do that with just @loanOpen.
        const isClosed = await employmentLoan.isClosed()
        assert.equal(isClosed, true);

        assert.equal(
            lenderFlowRateAfterCompletion.flowRate,
            0,
            "lender flow rate should now be zero"
        )
        assert.equal(
            borrowerFlowRateAfterCompletion.flowRate,
            employerFlowRateAfterCompletion.flowRate,
            "employer should now send 100% of flow to employee"
        )
        assert.isAtLeast(
            Number(Number(lenderBalBefore) + Number(amountLeft)),
            Number(lenderBalBefore),
            "lender should see increase in borrow token balance"
        )
    })

    it("10 closing the loan early from lender", async function () {
        //other party sends payment to pay off loan
        let borrowAmount = ethers.utils.parseEther("1000")
        let interest = 10
        let paybackMonths = 12

        await loanFactory.createNewLoan(
            borrowAmount, //borrowing 1000 fDAI tokens
            interest, // 10% annual interest
            paybackMonths, //in months
            employer.address, //address of employer
            borrower.address, //address of borrower
            daix.address,
            sf.settings.config.hostAddress
        )

        let loan2Address = await loanFactory.idToLoan(2)
        let employmentLoan2 = new ethers.Contract(
            loan2Address,
            LoanArtifact.abi,
            admin
        )

        await dai.connect(borrower).mint(borrower.address, alotOfEth);
        await dai.connect(borrower).approve(daix.address, alotOfEth)
        await daix.upgrade({amount: alotOfEth}).exec(borrower);
        
        await daix.transfer({receiver: employmentLoan2.address, amount: alotOfEth}).exec(borrower);

        //create flow
            
        const createFlowOperation = daix.createFlow({
            receiver: employmentLoan2.address,
            flowRate: "3215019290123456"
        })

        await createFlowOperation.exec(employer)

        //lend

        await daix.approve({receiver: employmentLoan2.address, amount: borrowAmount.toString()}).exec(lender);

        //SENDING A SMALL AMOUNT OF FUNDS INTO CONTRACT FOR BUFFER
        // await daix.transfer({receiver: employmentLoan.address, amount: ethers.utils.parseEther("100")}).exec(employer);

        await employmentLoan2.connect(lender).lend()

        //make sure it worked
        const borrowerFlow = await daix.getFlow({
            sender: employmentLoan2.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const lenderFlow = await daix.getFlow({
            sender: employmentLoan2.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const employerFlow = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan2.address,
            providerOrSigner: employer
        })

        let pass6Months = 86400 * (365 / 2)
        await network.provider.send("evm_increaseTime", [pass6Months])
        await network.provider.send("evm_mine")

        //close loan before it ends
        await employmentLoan2.connect(lender).closeOpenLoan(0)

        const borrowerFlowAfter = await daix.getFlow({
            sender: employmentLoan2.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const lenderFlowAfter = await daix.getFlow({
            sender: employmentLoan2.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const loanStatus = await employmentLoan2.loanOpen()
        assert.equal(loanStatus, false)

        const isClosed = await employmentLoan2.isClosed()
        assert.equal(isClosed, true);

        assert.isBelow(
            Number(borrowerFlow.flowRate),
            Number(employerFlow.flowRate),
            "borrower flow rate should be less than total amount sent into loan by employer prior to the closing of the loan"
        )
        assert.isAbove(
            Number(lenderFlow.flowRate),
            0,
            "lender should have positive flow rate prior to loan ending"
        )
        assert.equal(
            borrowerFlowAfter.flowRate,
            employerFlow.flowRate,
            "borrower flow after loan ends should be equal to full value of employer flow"
        )
        assert.equal(
            lenderFlowAfter.flowRate,
            0,
            "lender flow rate should be zero after"
        )
    })

    it("11 borrower closing the loan once completed", async function () {
        //borrower closes loan once complete
        let borrowAmount = ethers.utils.parseEther("1000")
        let interest = 10
        let paybackMonths = 12

        await loanFactory.createNewLoan(
            borrowAmount, //borrowing 1000 fDAI tokens
            interest, // 10% annual interest
            paybackMonths, //in months
            employer.address, //address of employer
            borrower.address, //address of borrower
            daix.address,
            sf.settings.config.hostAddress
        )

        let loan3Address = await loanFactory.idToLoan(3)

        let employmentLoan3 = new ethers.Contract(
            loan3Address,
            LoanArtifact.abi,
            admin
        )


        await dai.connect(borrower).mint(borrower.address, alotOfEth)
        await dai.connect(borrower).approve(daix.address, alotOfEth);
        await daix.upgrade({amount: alotOfEth}).exec(borrower);
        await daix.transfer({receiver: employmentLoan3.address, amount: alotOfEth}).exec(borrower);

        //create flow

        const createLoan3FlowOperation = daix.createFlow({
            receiver: employmentLoan3.address,
            flowRate: "3215019290123456"
        })

        await createLoan3FlowOperation.exec(employer)

        //lend

        await daix.approve({receiver: employmentLoan3.address, amount: borrowAmount.toString()}).exec(lender);

        //SENDING A SMALL AMOUNT OF FUNDS INTO CONTRACT FOR BUFFER
        await daix.transfer({receiver: employmentLoan.address, amount: ethers.utils.parseEther("100")}).exec(employer);

        await employmentLoan3.connect(lender).lend()

        //make sure it worked
        const borrowerFlow = await daix.getFlow({
            sender: employmentLoan3.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const lenderFlow = await daix.getFlow({
            sender: employmentLoan3.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const employerFlow = await daix.getFlow({
            sender: employer.address,
            receiver: employmentLoan3.address,
            providerOrSigner: employer
        })

        //we will close loan 1 hour after the loan expires
        let passLoanDuration = 86400 * (365 / 12) * paybackMonths + 3600
        await network.provider.send("evm_increaseTime", [passLoanDuration])
        await network.provider.send("evm_mine")

        //close loan before it ends
        await employmentLoan3.connect(borrower).closeCompletedLoan()

        const borrowerFlowAfter = await daix.getFlow({
            sender: employmentLoan3.address,
            receiver: borrower.address,
            providerOrSigner: borrower
        })

        const lenderFlowAfter = await daix.getFlow({
            sender: employmentLoan3.address,
            receiver: lender.address,
            providerOrSigner: lender
        })

        const loanStatus = await employmentLoan3.loanOpen();
        assert.equal(loanStatus, false);

        const isClosed = await employmentLoan3.isClosed()
        assert.equal(isClosed, true);

        assert.isBelow(
            Number(borrowerFlow.flowRate),
            Number(employerFlow.flowRate),
            "borrower flow rate should be less than total amount sent into loan by employer prior to the closing of the loan"
        );
        assert.isAbove(
            Number(lenderFlow.flowRate),
            0,
            "lender should have positive flow rate prior to loan ending"
        );;
        assert.equal(
            borrowerFlowAfter.flowRate,
            employerFlow.flowRate,
            "borrower flow after loan ends should be equal to full value of employer flow"
        );
        assert.equal(
            lenderFlowAfter.flowRate,
            0,
            "lender flow rate should be zero after"
        );
    });
});