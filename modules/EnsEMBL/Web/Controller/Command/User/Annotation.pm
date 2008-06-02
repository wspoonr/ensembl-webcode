package EnsEMBL::Web::Controller::Command::User::Annotation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If editing, ensure that this record belongs to the logged-in user!
  my $cgi = new CGI;
  my $record;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::Annotation', $cgi->param('id'), $cgi->param('owner_type'));
  }
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
  my $self = shift;

warn "Rendering page Annotation";
  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new;
  my $data = EnsEMBL::Web::Data::Record::Annotation::User->new($cgi->param('id'));
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success($self->url('/User/Account'));
  $interface->on_failure($self->url('/User/UpdateFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({add  => 'Create annotation'});
  $interface->caption({edit => 'Edit annotation'});
  $interface->permit_delete('yes');
  $interface->element('title',      {type => 'String', label =>'Title'});
  $interface->element('annotation', {type =>'Text'   , label =>'Annotation notes'});
  $interface->element('stable_id',  {type =>'NoEdit' , label =>'Stable ID'});
  $interface->element('url',        {type =>'Hidden'});
  $interface->element('owner_type', {type => 'Hidden'});
  $interface->element_order(qw/stable_id title annotation url owner_type/);

  ## Render page or munge data, as appropriate
  $webpage->render_message($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
