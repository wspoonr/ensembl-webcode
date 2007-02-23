package EnsEMBL::Web::Controller::Command::User::Activate;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::Authentication->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::Logging->new);
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    print "Content-type:text/html\n\n";
    print $self->filters->message; 
  }
}

sub render_page {
  my $self = shift;

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data =EnsEMBL::Web::Object::Data::User->new();;
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('confirm');
  $interface->panel_header({'confirm'=>qq(<p><strong>Thanks for confirming your email address.</strong></p><p>To start using your new Ensembl user account, just choose a password below. You'll need to use this password each time you log in to Ensembl.</p>)});
  $interface->on_success('/common/set_cookie');
  $interface->on_failure('EnsEMBL::Web::Component::Interface::User::failed_activation');
  $interface->caption({'on_failure'=>'Activation Failed'});
  $interface->script_name($self->get_action->script_name);

  ## N.B. Form elements are configured in the components, because they are a bit weird!

  ## Render page or munge data, as appropriate
  ## N.B. Force use of Configuration subclass
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::User');

}

}

1;
