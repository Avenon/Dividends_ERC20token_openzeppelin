pragma solidity ^0.4.19;

import './MintableToken.sol';


/**
 * Мой контракт, унаследован от контракта MintableToken
 */
contract MyTestToken is MintableToken {

    string public constant name = "Simple Coin Token";

    string public constant symbol = "SCT";

    uint32 public constant decimals = 18;

}

contract Crowdsale is Ownable {

    using SafeMath for uint;

    // укажем счет-экскроу, на который будет поступать эфир от инвесторов
    address multisig;

    // Переменная для хранения процента дивидендов, в нашем случае 10%
    uint sharesPercent;

    MyTestToken public token = new MyTestToken();

    // Дата начала ICO
    uint start;

    // Период ICO
    uint period;

    // Период, через который держатели токенов, смогут получить дивиденды
    uint periodDividends;

    uint hardcap;

    // Коэфициент пересчета, в нашем случае будет 1 эфир = 10 токенам
    uint rate;

    // Посчитаем держателей наших токенов, в данной переменной, будет храниться
    // количество наших инвесторов
    uint sharesCount;

    // Переменная в которой будет храниться дата выплаты дивидендов, будет
    // обновляться после каждой выплаты (в нашем случае через каждые 18 месяцев)
    uint public startPayPeriodDividends;

    // Будем в мэппинг записывать наших держателей
    mapping (uint => address) shareholders;

    // добавим события для логирования выплаты дивидендов
    event Dividends(address shareholder, uint256 value);

    function Crowdsale() {
        // Account 3 в метамаске
        multisig = 0x0D8d9Dd4a25d48F891DAD41Ca17C23c0b3e794AF;
        sharesPercent = 10;
        rate = 10 * (10 ** 18);
        // 04.02.2018 12:00 - начало ICO
        start = 1517745600;
        // Пусть наше ico длится 12 дней, ниже добавим модификатор, где будем
        // это проверять
        period = 12;
        periodDividends = 18;

        // Инициализируем переменную датой, раньше которой дивиденды не могут
        // быть уплачены
        startPayPeriodDividends = start + period * 1 days + (1 years + (1 years / 2));
        // Пусть для нашего ico необходима сумма в 100 эфиров, при достижении
        // этой суммы прекращаем продажу токенов
        hardcap = 100 * (10 ** 18);
        sharesCount = 0;
    }

    modifier saleIsOn() {
        require(now > start && now < start + period * 1 days);
        _;
    }

    // В данном модификаторе будем проверять, что с момента окончания ico
    // прошло достаточное количества месяцев для выплаты дивидендов
    // Проверямем, что дата выплаты наступила
    modifier periodDividendsIsOn() {
        //require(now > (start + period * 1 days) + (1 years + (1 years / 2)));
        require(now > startPayPeriodDividends);
        _;
    }

    modifier isUnderHardCap() {
        require(multisig.balance <= hardcap);
        _;
    }

    function finishMinting() public onlyOwner {
        // После окончания эмиссии токенов, выпустим долю токенов для наших нужд
        // в нашем случае это 10% для выплаты дивидендов
        uint issuedTokenSupply = token.totalSupply();
        uint restrictedTokens = issuedTokenSupply.mul(sharesPercent).div(100);
        token.mint(this, restrictedTokens);
        token.finishMinting();
    }

    function createTokens() isUnderHardCap saleIsOn payable {
        multisig.transfer(msg.value);
        // Переводим присланный эфир по курсу выше и по курсу делаем выпуск
        // токенов, например для присланных 10 эфиров будет выпущено 100 токенов
        uint tokens = rate.mul(msg.value).div(1 ether);
        token.mint(msg.sender, tokens);
        // Запишем адреса владельцев токена
        shareholders[sharesCount] = msg.sender;
        sharesCount += 1;
    }

    // fallback функция срабатывает в момент получения эфира
    function() external payable {
        createTokens();
    }

    function getDividendsManually() periodDividendsIsOn {
        // Проверим баланс токенов, и от фактического остатка начислим 10% токенов
        // в виде дивидендов
        require(token.balanceOf(msg.sender) > 0);
        uint value = token.balanceOf(msg.sender).mul(sharesPercent).div(100);
        token.transfer(msg.sender, value);
    }

    function payDividends() onlyOwner periodDividendsIsOn {
        for (uint i = 0; i < sharesCount; i++) {
            uint256 currentBalance = token.balanceOf(shareholders[i]);

            if (currentBalance > 0) {
                uint256 dividends = currentBalance.mul(sharesPercent).div(100);
                token.transfer(shareholders[i], dividends);
            }
            Dividends(shareholders[i], dividends);
        }
        // Обновляем дату выплаты дивидендов до следующей выплаты
        startPayPeriodDividends = startPayPeriodDividends + (1 years + (1 years / 2));
    }

}
