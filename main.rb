require 'rubygems'
require 'sinatra'
require 'pry'


# set :sessions, true
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'crazy_bubba'

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_PLAYER_AMOUNT = 1000

helpers do
  def calculate_total(cards)
    arr = cards.map{|element| element[1]}

    total = 0
    arr.each do |a|
      if a == 'A'
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    # to adjust for aces
    arr.select{|e| e == 'A'}.count.times do
      total -= 10 if total > BLACKJACK_AMOUNT
    end
  total
  end

  def card_image(card)
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J','Q','K','A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end
  "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def player_blackjack?(cards)
    player_total = calculate_total(cards)

    if player_total == BLACKJACK_AMOUNT && cards.count == 2
      winner!("Congratulations!  #{session[:player_name]} hit Blackjack!")
      @show_hit_or_stay_buttons = false
    end
  end

  def dealer_blackjack?(cards)
    dealer_total = calculate_total(cards)

    if dealer_total == BLACKJACK_AMOUNT && cards.count == 2
      loser!("Drats!  The Dealer hit Blackjack!")
      @show_hit_or_stay_buttons = false
    end
  end

  def winner!(msg)
      @show_dealer_hit_button = false
      @winner = "<strong> #{session[:player_name]} wins!</strong> #{msg}"
      session[:player_amount] += session[:player_bet]
      @play_again = true

  end

  def loser!(msg)
      @show_dealer_hit_button = false
      @loser = "<strong> #{session[:player_name]} loses!</strong> #{msg}"
      session[:player_amount] -= session[:player_bet]
      @play_again = true
  end

  def tie!(msg)
      @show_dealer_hit_button = false
      @winner = "<strong> #{session[:player_name]} ties the house!</strong> #{msg}"
      @play_again = true
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:user_name]
    redirect '/bet' # progress to game
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_amount] = INITIAL_PLAYER_AMOUNT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required!"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name].capitalize
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i <= 0
    @error = "Must make a bet with an amount more than 0!"
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_amount]
    @error = "Reduce your bet to an amount you can afford -> you have $#{session[:player_amount]}."
    halt erb(:bet)
  else #happy path
    session[:player_bet] = params[:bet_amount].to_i
    redirect'/game'
  end
end

get '/game' do
  #set turn
  session[:turn] = session[:player_name]

  # create cards and shuffle deck
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8','9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  # initialize empty hands then deal dealer and player cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  dealer_blackjack?(session[:dealer_cards])
  player_blackjack?(session[:player_cards])
  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total > BLACKJACK_AMOUNT
    loser!("Sorry, it looks like #{session[:player_name]} busted with #{player_total}!")
    @show_hit_or_stay_buttons = false
  end
  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
  # next, prompt dealer to hit!
end

get '/game/dealer' do
  @show_hit_or_stay_buttons = false
  session[:turn] = "dealer"

  # decision tree
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total > BLACKJACK_AMOUNT
    winner!("Congratulations, the dealer busted.")
  elsif dealer_total >= DEALER_MIN_HIT
    #dealer stays
    redirect '/game/compare'
  else
    # dealer hits
    @show_dealer_hit_button = true
  end
  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false
  @show_dealer_hit_button = false

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total > dealer_total
    winner!("#{session[:player_name]} has #{player_total} and the dealer stayed at #{dealer_total}.")
  elsif player_total < dealer_total
    loser!("#{session[:player_name]} has #{player_total} and the dealer stayed at #{dealer_total}.")
  else
    tie!("It's a push - #{session[:player_name]} and the dealer both have #{player_total}.")
  end
  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end
