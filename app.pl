#!/usr/bin/env perl
use Mojolicious::Lite;
use Modern::Perl;
use Furl;
use URI;
use JSON qw/encode_json decode_json/;
use Data::Dumper;

app->secret("gifboom is great!!!!!");
app->log->level('info');

get '/' => sub {
  my $self = shift;
  $self->render('index');
};

get '/show' => sub {
  my $self = shift;

  my $username = $self->param('username');
  return $self->render_not_found
    unless $username;

  my $f = new Furl(
    'headers' => [ 
        'Accept'=> '*/*', # probably require 
        ]
    );
  my $uri = URI->new("http://api.gifboom.com");

  # get user info
  $uri->path('v1/users/search');
  $uri->query_form("q" => $username);
  $self->app->log->debug("Gifboom API URL:". $uri->as_string);
  my $res = $f->get($uri);
  return $self->render_exception('fail gifboom api access.')
    unless $res->is_success;

  my $data = decode_json($res->content); 
  my $user_data = $data->{data}[0];
  $self->app->log->debug("User data:".Dumper($user_data));

  my $gb_uid = $user_data->{_id};
  $self->app->log->info("User _id: $gb_uid");

  # get feed
  $uri->path('v1/feed/user_timeline');
  my $page = 1;
  my @feed_list;
  my $limitter = 20; # hard limitter.
  do{
    $limitter--;
    $self->app->log->debug("get page $page");
    $uri->query_form("user_id" => $gb_uid, 'page'=>$page);
    $self->app->log->debug("Gifboom API URL:". $uri->as_string);
    $res = $f->get($uri);
    return $self->render_exception('fail gifboom api access.')
      unless $res->is_success;
  
    $data = decode_json($res->content); 
    $self->app->log->debug("Feed data:".Dumper(@{$data->{data}}));
    push @feed_list, @{$data->{data}};
    $page = $data->{paging}->{next};
  }while($page ne '-1' && 0 < $limitter);

  $self->stash('gb_user_data', $user_data);
  $self->stash('gb_feed_list', \@feed_list);

  $self->render('show');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'gifboomer';
% param username => 'uzulla' unless param 'username';
%= form_for show => (method => 'GET') => begin
    screen name: <%= input_tag 'username' %>
    %= submit_button
% end

<!------------------------------------------------------------------------------------->
@@ show.html.ep
% use Data::Dumper;
% layout 'default';
% title 'gifboomer : '.$username;
%= form_for show => (method => 'GET') => begin
    screen name: <%= input_tag 'username' %>
    %= submit_button
% end
<hr>
%= image $gb_user_data->{avatar}
%= $gb_user_data->{username}
<hr>
<style>
.thumb_img{
    height:200px;
}
</style>
% for my $_i ( @$gb_feed_list ) {
    % my $m = $_i->{medias}[0]; 
    % next unless ($_i->{medias}[0]) ;
    <%= link_to $m->{full_url} => begin %><%=image $m->{thumb_url}, class=>'thumb_img' %><% end %>    
% }

<!------------------------------------------------------------------------------------->
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
