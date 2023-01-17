// SPDX-License-Identifier: GPL-3.0


pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract UniswapV2AMM{

// Token Contracts 
IERC20 private immutable token1;
IERC20 private immutable token2;

// Balances mapping
mapping(address=>uint) public balanceOf;

// reserve variables
uint private reserve1;
uint private reserve2;
// 
uint totalSupply;


constructor(address _token1, address _token2){
token1=IERC20(_token1);
token2=IERC20(_token2);
totalSupply=0;
}



function _mint(address _to ,uint amount)public {
    balanceOf[_to]+=amount;
    totalSupply+=amount;
}

function _burn(address _from,uint amount)public {
    balanceOf[_from]-=amount;
totalSupply-=amount;
}


function updateReserves(uint res1,uint res2)internal{
reserve1 =res1;
reserve2 = res2;


}
/*

Step1 - Check if the token that user is sending , is a valid token.
Step2 - Maintain local variables for reserve of tokens to be received( tokenIn)
        and tokens to be sent to user (tokenOut)
Step3 - Accept / transfer the tokens from user to the platform / contract.
Step4 - Calculate the tokensOut to be transferred to the user by incurring interest - 0.03%
Step5 - Send tokensOut to the user 
Step6 - Update the reserves


*/
function swap(address _tokenIn,uint amountIn )public returns(uint amountOut){

require(_tokenIn==address(token1) || _tokenIn ==address(token2) ,"Invalid token");
require(amountIn>0,"Amount is 0");


// detect which token is user wants to trade in and which to trade out


(IERC20 tokenIn, IERC20 tokenOut,
uint reserveIn,uint reserveOut)=
 _tokenIn==address(token1)?
(token1,token2,reserve1,reserve2):
(token2,token1,reserve2,reserve1);

// Take token from the user
tokenIn.transferFrom(msg.sender,address(this),amountIn);

// Calculate tokensOut to transfer including fees (0.3%)
uint amountInWithFee=(amountIn*997)/1000;

// CPMM y*dx/(x+dx)=dy

amountOut=reserveOut*amountInWithFee/(reserveIn+amountInWithFee);


// transfer tokenOut to user
tokenOut.transfer(msg.sender,amountOut);
//update reserves

updateReserves(
    token1.balanceOf(address(this)),
    token2.balanceOf(address(this))
);

}

/*
Step1 - transfer both tokens sent by the user.
Step2 - Make sure we have enough reserves for both tokens , say greater than zero
Step3 - Calculate shares of liquidity tokens to give to the user.
        -   supply is 0
            -   mint / give the product amount of tokens of the tokens sent by the user -  amount1 * amount2 
        -   supply is non-zero
            -   shares= min(( (dx*TotalSupply)/x ), ( (dy*TotalSupply)/y )

Step4 - mint shares onto address of the user
Step5 - update reserves

)

*/

function addLiquidity(uint amount1,uint amount2)external {

token1.transferFrom(msg.sender,address(this),amount1);
token2.transferFrom(msg.sender,address(this),amount2);

// In order to not degrade the prices of the tokens
// using a CPMM formula

// following should hold for adding liquidity

// dy/dx == y/x   or dy*x == y*dx 

// This holds if we have non zero reserves for both tokens

if(reserve1>0 || reserve2>0){
    require(reserve1*amount2==reserve2*amount1,"Invalid Liquidity");
}


// Amount of shares to give to the liquidity provider
uint shares=0;
if(totalSupply==0){
    // shares= sqrt(dy*dx)
    shares=_sqrt(amount1*amount2);

}else{
/*
 shares= min(
    ( (dx*TotalSupply)/x ),
    ( (dy*TotalSupply)/y )
)
*/
shares=_min(
     (amount1*totalSupply)/reserve1 ,
     (amount2*totalSupply)/reserve2 
);

}

require(shares>0,"No shares");

// give shares to senders
_mint(msg.sender,shares);
//update reserves
updateReserves(
    token1.balanceOf(address(this)),
    token2.balanceOf(address(this))
);

}


/*
Step1 - calculate the current balance of tokens the contract holds
Step2 - calculate the total tokens the user will get for both token1 and token2
Step3 - burn the shares of the user
Step4 - update reserves
Step5 - send both tokens to user


*/
function removeLiquidity(uint shares)external {
require(shares>0 && balanceOf[msg.sender]>=shares,"Invalid Amount of shares");

uint bal1=token1.balanceOf(address(this));
uint bal2=token2.balanceOf(address(this));

// Amount of tokens the user will get 

// dx = shares*TotalTokenX/totalSuuply
// dy = shares*TotalTokenY/totalSuuply

uint amount1 = shares*bal1/totalSupply;
uint amount2 = shares*bal2/totalSupply;

require(amount1 >0 && amount2>0,"Invalid token amounts to transfer");

_burn(msg.sender,shares);
updateReserves(
    bal1-amount1,
    bal2-amount2
);


// transfer tokens in exchange of liquidity
token1.transfer(msg.sender,amount1);
token2.transfer(msg.sender,amount2);

}



/*          Utility function for finding square root of a number*/

function _sqrt(uint y) internal pure returns (uint z) {
    if (y > 3) {
        z = y;
        uint x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    } else if (y != 0) {
        z = 1;
    }
}

/*          Utility function for finding minimum of two numbers*/

function _min(uint x,uint y)private returns(uint){
return x<=y?x:y;
}


}
