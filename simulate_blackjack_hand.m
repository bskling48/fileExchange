% SIMULATE_BLACKJACK_HAND Simulate one blackjack round using basic strategy.
% Run this script directly in MATLAB. It leaves a struct named RESULT in the
% workspace and prints a short action log.
%
% Optional:
%   seed = 1;
%   simulate_blackjack_hand

if ~exist('seed', 'var')
    seed = [];
end

if ~isempty(seed)
    rng(seed);
end

rules.numDecks = 6;
rules.maxHands = 4;
rules.blackjackPayout = 1.5;
rules.dealerHitsSoft17 = false;

[shoe, shoePos] = makeShoe(rules.numDecks);
logLines = {};

playerHands = makeEmptyHand();

[playerHands(1).cards, shoePos] = drawCard(playerHands(1).cards, shoe, shoePos);
[dealerCards, shoePos] = drawCard([], shoe, shoePos);
[playerHands(1).cards, shoePos] = drawCard(playerHands(1).cards, shoe, shoePos);
[dealerCards, shoePos] = drawCard(dealerCards, shoe, shoePos);

logLines{end+1} = sprintf('Dealer shows %s.', cardToString(dealerCards(1))); %#ok<AGROW>
logLines{end+1} = sprintf('Player starts with %s.', handToString(playerHands(1).cards)); %#ok<AGROW>

playerHands(1).isBlackjack = isNaturalBlackjack(playerHands(1));
dealerBlackjack = isNaturalBlackjack(struct('cards', dealerCards, 'isSplitAce', false));

if dealerBlackjack
    logLines{end+1} = sprintf('Dealer has blackjack: %s.', handToString(dealerCards)); %#ok<AGROW>
    if playerHands(1).isBlackjack
        playerHands(1).outcome = 'push';
        playerHands(1).profit = 0;
        logLines{end+1} = 'Player also has blackjack: push.'; %#ok<AGROW>
    else
        playerHands(1).outcome = 'lose';
        playerHands(1).profit = -playerHands(1).bet;
        logLines{end+1} = 'Player loses to dealer blackjack.'; %#ok<AGROW>
    end

    result = buildResult(playerHands, dealerCards, dealerBlackjack, rules, logLines);
    printResult(result);
    return;
end

if playerHands(1).isBlackjack
    playerHands(1).outcome = 'blackjack';
    playerHands(1).profit = rules.blackjackPayout * playerHands(1).bet;
    logLines{end+1} = 'Player has a natural blackjack.'; %#ok<AGROW>

    result = buildResult(playerHands, dealerCards, dealerBlackjack, rules, logLines);
    printResult(result);
    return;
end

handIndex = 1;
while handIndex <= numel(playerHands)
    while ~playerHands(handIndex).finished
        canSplit = numel(playerHands(handIndex).cards) == 2 ...
            && numel(playerHands) < rules.maxHands ...
            && canBeSplit(playerHands(handIndex).cards) ...
            && ~playerHands(handIndex).isSplitAce;
        canDouble = numel(playerHands(handIndex).cards) == 2 ...
            && ~playerHands(handIndex).isSplitAce;

        action = basicStrategyAction(playerHands(handIndex).cards, dealerCards(1), canSplit, canDouble);
        logLines{end+1} = sprintf('Hand %d (%s) vs %s: %s.', ...
            handIndex, handToString(playerHands(handIndex).cards), ...
            cardToString(dealerCards(1)), actionName(action)); %#ok<AGROW>
        playerHands(handIndex).actions{end+1} = actionName(action); %#ok<AGROW>

        switch action
            case 'P'
                [playerHands, shoePos, logLines] = splitHand(playerHands, handIndex, shoe, shoePos, logLines);
            case 'D'
                playerHands(handIndex).bet = 2 * playerHands(handIndex).bet;
                [playerHands(handIndex).cards, shoePos] = drawCard(playerHands(handIndex).cards, shoe, shoePos);
                playerHands(handIndex).finished = true;
                logLines{end+1} = sprintf('Hand %d draws %s and doubles to %s.', ...
                    handIndex, cardToString(playerHands(handIndex).cards(end)), ...
                    handToString(playerHands(handIndex).cards)); %#ok<AGROW>
            case 'H'
                [playerHands(handIndex).cards, shoePos] = drawCard(playerHands(handIndex).cards, shoe, shoePos);
                logLines{end+1} = sprintf('Hand %d hits %s and now has %s.', ...
                    handIndex, cardToString(playerHands(handIndex).cards(end)), ...
                    handToString(playerHands(handIndex).cards)); %#ok<AGROW>
                if handTotal(playerHands(handIndex).cards) > 21
                    playerHands(handIndex).finished = true;
                    logLines{end+1} = sprintf('Hand %d busts.', handIndex); %#ok<AGROW>
                end
            case 'S'
                playerHands(handIndex).finished = true;
        end
    end

    handIndex = handIndex + 1;
end

allBust = all(arrayfun(@(h) handTotal(h.cards) > 21, playerHands));
if allBust
    logLines{end+1} = 'All player hands busted; dealer does not draw.'; %#ok<AGROW>
else
    logLines{end+1} = sprintf('Dealer reveals %s.', handToString(dealerCards)); %#ok<AGROW>
    while true
        [dealerTotal, dealerSoft] = handTotal(dealerCards);
        if dealerTotal < 17 || (dealerTotal == 17 && dealerSoft && rules.dealerHitsSoft17)
            [dealerCards, shoePos] = drawCard(dealerCards, shoe, shoePos);
            logLines{end+1} = sprintf('Dealer hits %s and now has %s.', ...
                cardToString(dealerCards(end)), handToString(dealerCards)); %#ok<AGROW>
        else
            break;
        end
    end
end

[dealerTotal, ~] = handTotal(dealerCards);
for k = 1:numel(playerHands)
    playerTotal = handTotal(playerHands(k).cards);
    if playerTotal > 21
        playerHands(k).outcome = 'lose';
        playerHands(k).profit = -playerHands(k).bet;
    elseif dealerTotal > 21
        playerHands(k).outcome = 'win';
        playerHands(k).profit = playerHands(k).bet;
    elseif playerTotal > dealerTotal
        playerHands(k).outcome = 'win';
        playerHands(k).profit = playerHands(k).bet;
    elseif playerTotal < dealerTotal
        playerHands(k).outcome = 'lose';
        playerHands(k).profit = -playerHands(k).bet;
    else
        playerHands(k).outcome = 'push';
        playerHands(k).profit = 0;
    end

    logLines{end+1} = sprintf('Hand %d ends %s with %s vs dealer %s.', ...
        k, playerHands(k).outcome, handToString(playerHands(k).cards), handToString(dealerCards)); %#ok<AGROW>
end

result = buildResult(playerHands, dealerCards, false, rules, logLines);
printResult(result);

function hand = makeEmptyHand()
hand = struct( ...
    'cards', [], ...
    'bet', 1, ...
    'actions', {{}}, ...
    'finished', false, ...
    'isSplitAce', false, ...
    'isBlackjack', false, ...
    'outcome', '', ...
    'profit', 0);
end

function [shoe, shoePos] = makeShoe(numDecks)
shoe = repmat(1:13, 1, 4 * numDecks);
shoe = shoe(randperm(numel(shoe)));
shoePos = 1;
end

function [cards, shoePos] = drawCard(cards, shoe, shoePos)
cards(end+1) = shoe(shoePos);
shoePos = shoePos + 1;
end

function tf = isNaturalBlackjack(hand)
isSplitAce = isfield(hand, 'isSplitAce') && hand.isSplitAce;
tf = numel(hand.cards) == 2 && handTotal(hand.cards) == 21 && ~isSplitAce;
end

function [hands, shoePos, logLines] = splitHand(hands, handIndex, shoe, shoePos, logLines)
original = hands(handIndex);
firstCard = original.cards(1);
secondCard = original.cards(2);

firstHand = makeEmptyHand();
secondHand = makeEmptyHand();
firstHand.bet = original.bet;
secondHand.bet = original.bet;
firstHand.cards = firstCard;
secondHand.cards = secondCard;
firstHand.actions = original.actions;
secondHand.actions = original.actions;
firstHand.isSplitAce = firstCard == 1;
secondHand.isSplitAce = secondCard == 1;

[firstHand.cards, shoePos] = drawCard(firstHand.cards, shoe, shoePos);
[secondHand.cards, shoePos] = drawCard(secondHand.cards, shoe, shoePos);

if firstHand.isSplitAce
    firstHand.finished = true;
end
if secondHand.isSplitAce
    secondHand.finished = true;
end

hands(handIndex) = firstHand;
hands = [hands(1:handIndex), secondHand, hands(handIndex+1:end)]; %#ok<AGROW>

logLines{end+1} = sprintf('Split hand %d into %s and %s.', ...
    handIndex, handToString(firstHand.cards), handToString(secondHand.cards)); %#ok<AGROW>
end

function action = basicStrategyAction(cards, dealerUpCard, canSplit, canDouble)
dealerValue = strategyDealerValue(dealerUpCard);
pairValue = splitValue(cards);

if canSplit && shouldSplit(pairValue, dealerValue)
    action = 'P';
    return;
end

[total, isSoft] = handTotal(cards);

if isSoft
    if canDouble && shouldDoubleSoft(total, dealerValue)
        action = 'D';
    elseif shouldStandSoft(total, dealerValue)
        action = 'S';
    else
        action = 'H';
    end
else
    if canDouble && shouldDoubleHard(total, dealerValue)
        action = 'D';
    elseif shouldStandHard(total, dealerValue)
        action = 'S';
    else
        action = 'H';
    end
end
end

function tf = shouldSplit(pairValue, dealerValue)
switch pairValue
    case 1
        tf = true;
    case 2
        tf = dealerValue >= 2 && dealerValue <= 7;
    case 3
        tf = dealerValue >= 2 && dealerValue <= 7;
    case 4
        tf = dealerValue == 5 || dealerValue == 6;
    case 5
        tf = false;
    case 6
        tf = dealerValue >= 2 && dealerValue <= 6;
    case 7
        tf = dealerValue >= 2 && dealerValue <= 7;
    case 8
        tf = true;
    case 9
        tf = any(dealerValue == [2 3 4 5 6 8 9]);
    case 10
        tf = false;
    otherwise
        tf = false;
end
end

function tf = shouldDoubleHard(total, dealerValue)
tf = false;
switch total
    case 9
        tf = dealerValue >= 3 && dealerValue <= 6;
    case 10
        tf = dealerValue >= 2 && dealerValue <= 9;
    case 11
        tf = dealerValue >= 2 && dealerValue <= 10;
end
end

function tf = shouldStandHard(total, dealerValue)
if total >= 17
    tf = true;
elseif total >= 13 && total <= 16
    tf = dealerValue >= 2 && dealerValue <= 6;
elseif total == 12
    tf = dealerValue >= 4 && dealerValue <= 6;
else
    tf = false;
end
end

function tf = shouldDoubleSoft(total, dealerValue)
tf = false;
switch total
    case 13
        tf = dealerValue == 5 || dealerValue == 6;
    case 14
        tf = dealerValue == 5 || dealerValue == 6;
    case 15
        tf = dealerValue >= 4 && dealerValue <= 6;
    case 16
        tf = dealerValue >= 4 && dealerValue <= 6;
    case 17
        tf = dealerValue >= 3 && dealerValue <= 6;
    case 18
        tf = dealerValue >= 3 && dealerValue <= 6;
    case 19
        tf = dealerValue == 6;
end
end

function tf = shouldStandSoft(total, dealerValue)
if total <= 17
    tf = false;
elseif total == 18
    tf = any(dealerValue == [2 7 8]);
else
    tf = true;
end
end

function tf = canBeSplit(cards)
tf = numel(cards) == 2 && splitValue(cards) > 0;
end

function value = splitValue(cards)
if numel(cards) ~= 2
    value = 0;
    return;
end

v1 = blackjackCardValue(cards(1));
v2 = blackjackCardValue(cards(2));
if cards(1) == 1 && cards(2) == 1
    value = 1;
elseif v1 == 10 && v2 == 10
    value = 10;
elseif v1 == v2
    value = v1;
else
    value = 0;
end
end

function dealerValue = strategyDealerValue(card)
if card == 1
    dealerValue = 11;
else
    dealerValue = blackjackCardValue(card);
end
end

function [total, isSoft] = handTotal(cards)
values = arrayfun(@blackjackCardValue, cards);
total = sum(values);
aces = sum(cards == 1);
while aces > 0 && total + 10 <= 21
    total = total + 10;
    aces = aces - 1;
end
isSoft = any(cards == 1) && total <= 21 && sum(values) ~= total;
end

function value = blackjackCardValue(card)
if card == 1
    value = 1;
else
    value = min(card, 10);
end
end

function text = handToString(cards)
[total, isSoft] = handTotal(cards);
cardNames = arrayfun(@cardToString, cards, 'UniformOutput', false);
joined = strjoin(cardNames, ', ');
if total > 21
    text = sprintf('[%s] = %d (bust)', joined, total);
elseif isSoft
    text = sprintf('[%s] = soft %d', joined, total);
else
    text = sprintf('[%s] = %d', joined, total);
end
end

function text = cardToString(card)
switch card
    case 1
        text = 'A';
    case 11
        text = 'J';
    case 12
        text = 'Q';
    case 13
        text = 'K';
    otherwise
        text = num2str(card);
end
end

function text = actionName(action)
switch action
    case 'H'
        text = 'hit';
    case 'S'
        text = 'stand';
    case 'D'
        text = 'double';
    case 'P'
        text = 'split';
    otherwise
        text = 'unknown';
end
end

function result = buildResult(playerHands, dealerCards, dealerBlackjack, rules, logLines)
result = struct();
result.rules = rules;
result.dealer.cards = dealerCards;
result.dealer.description = handToString(dealerCards);
result.dealer.blackjack = dealerBlackjack;
result.playerHands = playerHands;
result.totalProfit = sum([playerHands.profit]);
result.transcript = logLines;
end

function printResult(result)
for k = 1:numel(result.transcript)
    fprintf('%s\n', result.transcript{k});
end
fprintf('Total profit: %+0.1f units.\n', result.totalProfit);
end
