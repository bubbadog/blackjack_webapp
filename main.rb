require 'rubygems'
require 'sinatra'
require 'pry'


set :sessions, true

get '/' do
  redirect '/new_game'
end

get '/new_game' do
  erb :new_game
end

post '/new_game' do
  session[:player_name] = params[:player_name]
  session[:player_amount] = 500
  redirect '/bet'
end


get '/bet' do
  erb :bet
end

post '/bet' do
  # check if bet amount correct
  redirect '/game'
end

get '/game' do
  erb :game
end
