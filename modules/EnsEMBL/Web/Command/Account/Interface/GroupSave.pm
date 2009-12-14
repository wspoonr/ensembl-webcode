package EnsEMBL::Web::Command::Account::Interface::GroupSave;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/Account/Group';
  my $param = {
    '_referer' => $object->param('_referer'),
  }; 

  my $interface = $self->interface;
  $interface->cgi_populate($object);

  if ($interface->data->id) { ## Update group record
    my $success = $interface->data->save;
    if ($success) {
      $url .= '/List';
    }
    else {
      $url .= '/Problem';
    }
  }
  else { ## New group
    my $new_id = $interface->data->save;
    if ($new_id) {
      $url .= '/List';
      ## Add current user as creator and administrator
      my $group = new EnsEMBL::Web::Data::Group($new_id);
      my $user = $ENSEMBL_WEB_REGISTRY->get_user;
      $group->created_by($user->id);
      $group->save;
      $group->add_user($user, 'administrator');
    }
    else {
      $url .= '/Problem';
    }
  }

  $self->ajax_redirect($url, $param);
}

1;
