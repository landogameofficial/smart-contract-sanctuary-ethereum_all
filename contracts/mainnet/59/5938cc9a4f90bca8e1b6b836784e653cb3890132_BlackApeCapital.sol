/**
 *Submitted for verification at Etherscan.io on 2022-12-04
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*


______ _            _       ___               _____             _ _        _ 
| ___ \ |          | |     / _ \             /  __ \           (_) |      | |
| |_/ / | __ _  ___| | __ / /_\ \_ __   ___  | /  \/ __ _ _ __  _| |_ __ _| |
| ___ \ |/ _` |/ __| |/ / |  _  | '_ \ / _ \ | |    / _` | '_ \| | __/ _` | |
| |_/ / | (_| | (__|   <  | | | | |_) |  __/ | \__/\ (_| | |_) | | || (_| | |
\____/|_|\__,_|\___|_|\_\ \_| |_/ .__/ \___|  \____/\__,_| .__/|_|\__\__,_|_|
                                | |                      | |                 
                                |_|                      |_|                 

We ape together. We eat together.
Now do it in black.

NFTs.
Stake Pools.
Lot's of fucking money.

Black Ape Capital will be at the center of ape-style wealth creation.

Build the telegram community and wait for details.

Name: Black Ape Capital 
Symbol: BLACKAPE
Supply: 100,000,000
Decimals: 18

Launch Max Wallet/TXN: 1% (1,000,000)

Token Fees:
    2% Auto Liquidity
    2% Development Fee

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

}

interface IERC20 {

    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    function totalSupply() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);


    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

}

interface IERC20Metadata is IERC20 {

    function symbol() external view returns (string memory);
    function name() external view returns (string memory);

    function decimals() external view returns (uint8);

}

contract ERC20 is IERC20, IERC20Metadata {

    string private _symbol;
    string private _name;
    uint256 private _totalSupply;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _balances;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from zero address");
        require(recipient != address(0), "ERC20: transfer to zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount greater than balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount greater than allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }

        return true;
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract BlackApeCapital is ERC20, Ownable {

    uint256 public sellTotalFees;
    uint256 public maxTransactionAmount;
    uint256 public feeDenominator = 1000;
    uint256 public sellDevelopmentFee;
    uint256 public sellLiquidityFee;
    uint256 public buyTotalFees;
    uint256 public tokensForDevelopment;
    address public immutable amm;
    address public LPReceiver;
    uint256 public buyLiquidityFee;
    address public developmentWallet;

    uint256 public tokensForLiquidity;

    bool public limitsInEffect = true;
    mapping(address => bool) private feeless;
    uint256 public buyDevelopmentFee;

    uint256 public maxWallet;
    mapping(address => bool) public isExcludedMaxTxnAmt;
    bool private swapping;
    IUniswapV2Router02 public immutable router;

    constructor(address router_, address developmentWallet_, address LPReceiver_) ERC20("Black Ape Capital", "BLACKAPE") {

        router = IUniswapV2Router02(router_);

        amm = IUniswapV2Factory(
                router.factory()
        ).createPair(
            address(this),
            router.WETH()
        );
        LPReceiver = LPReceiver_;

        developmentWallet = developmentWallet_;
        isExcludedMaxTxnAmt[address(amm)] = true;
        isExcludedMaxTxnAmt[address(router)] = true;

        uint256 totalSupply = 100_000_000 * 1e18;

        uint256 _sellLiquidityFee = 20;
        uint256 _sellDevelopmentFee = 20;
        uint256 _buyLiquidityFee = 20;
        uint256 _buyDevelopmentFee = 20;

        isExcludedMaxTxnAmt[address(this)] = true;
        feeless[address(this)] = true;
        isExcludedMaxTxnAmt[address(0xdead)] = true;
        feeless[address(0xdead)] = true;
        buyLiquidityFee = _buyLiquidityFee;
        sellDevelopmentFee = _sellDevelopmentFee;
        sellLiquidityFee = _sellLiquidityFee;
        buyDevelopmentFee = _buyDevelopmentFee;

        buyTotalFees = buyLiquidityFee + buyDevelopmentFee;
        sellTotalFees = sellLiquidityFee + sellDevelopmentFee;

        maxTransactionAmount = totalSupply / 100;
        maxWallet = totalSupply / 100;


        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(this), totalSupply);
    }

    function swapBack() internal {
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForDevelopment;
        uint256 contractBalance = balanceOf(address(this));

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            // Reset to 0
            contractBalance = 0;
            totalTokensToSwap = 0;
            return;
        }

        uint256 lp = (contractBalance * tokensForLiquidity) / totalTokensToSwap / 2;
        uint256 amountToSwapForETH = contractBalance - lp;
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(amountToSwapForETH);
        uint256 ethBalance = (address(this).balance) - initialETHBalance;
        uint256 ethForDevelopment = ethBalance * tokensForDevelopment / totalTokensToSwap;
        uint256 ethForLiquidity = ethBalance - ethForDevelopment;
        tokensForDevelopment = 0;
        tokensForLiquidity = 0;

        if (lp > 0 && ethForLiquidity > 0 && balanceOf(address(amm)) < (totalSupply() * 15 / 100) ) {
            _addLiquidityETH(lp, ethForLiquidity, LPReceiver);
        }

        if (address(this).balance > 0) {
            bool success;
            (success, ) = payable(developmentWallet).call{value: address(this).balance}("");
        }
    }

    function swapTokensForEth(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    function _addLiquidityETH(uint256 tokenAmount, uint256 ethAmount, address tokenRecipient) internal {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount} (
            address(this),
            tokenAmount,
            0,
            0,
            tokenRecipient,
            block.timestamp
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0xdead) &&
                !swapping
            ) {

                if (
                    from == amm &&
                    !isExcludedMaxTxnAmt[to]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "!maxTransactionAmount."
                    );
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "!maxWallet"
                    );
                }

                else if (
                    to == amm &&
                    !isExcludedMaxTxnAmt[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "!maxTransactionAmount."
                    );
                } else if (!isExcludedMaxTxnAmt[to]) {
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "!maxWallet"
                    );
                }
            }
        }

        if (
            !swapping &&
            from != amm &&
            !feeless[from] &&
            !feeless[to]
        ) {
            swapping = true;

            swapBack();

            swapping = false;
        }

        bool takeFee = !swapping;

        if (feeless[from] || feeless[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        if (takeFee) {
            if (to == amm && sellTotalFees > 0) {
                fees = amount * sellTotalFees / feeDenominator;
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForDevelopment += (fees * sellDevelopmentFee) / sellTotalFees;
            }

            else if (from == amm && buyTotalFees > 0) {
                fees = amount * buyTotalFees / feeDenominator;
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForDevelopment += (fees * buyDevelopmentFee) / buyTotalFees;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function addInitialLiquidityAndStartTrading() external payable onlyOwner {
        _addLiquidityETH(balanceOf(address(this)), msg.value, developmentWallet);
    }

    receive() external payable {}

}