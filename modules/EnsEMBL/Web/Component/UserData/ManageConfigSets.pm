# $Id$

package EnsEMBL::Web::Component::UserData::ManageConfigSets;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::UserData::ManageConfigs);

sub empty    { return sprintf '<p>You have no configuration sets.</p>'; }
sub set_view { return 1; }

sub records {
  my ($self, $show_all, $record_ids) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my @sets    = values %{$adaptor->all_sets};

  return $self->empty unless scalar @sets;
  
  my ($rows, $json);
  
  $self->{'editables'} = { map { $_->{'type'} eq 'image_config' && $_->{'link_id'} ? () : ($_->{'record_id'} => $_) } values %{$self->deepcopy($adaptor->filtered_configs({ active => '' }))} };
  
  foreach (values %{$self->{'editables'}}) {
    my @config_code = split '::', $_->{'type'} eq 'view_config' ? $_->{'code'} : $_->{'link_code'};
    my $view_config = $hub->get_viewconfig(reverse @config_code);
    
    next unless $view_config;
    
    $_->{'conf_name'}  = join ' - ', $view_config->type, $view_config->title;
    $_->{'conf_codes'} = [ join '_', @config_code ];
  }
  
  foreach (sort { $a->{'name'} cmp $b->{'name'} } @sets) {
    my $record_id = $_->{'record_id'};
    
    next if $record_ids && !$record_ids->{$record_id};
    
    my @confs;
    
    foreach (map $self->{'editables'}{$_} || (), keys %{$_->{'records'}}) {
      push @confs, [ $_->{'record_id'}, $_->{'name'}, $_->{'conf_name'}, $_->{'conf_codes'} ] if $_->{'conf_name'};
    }
    
    my ($row, $row_key, $json_group) = $self->row($_, \@confs);
    
    push @{$rows->{$row_key}}, $row;
    
    $json->{$record_id} = {
      id        => $record_id,
      name      => $_->{'name'},
      group     => $json_group,
      codes     => [ map @{$_->[3]}, @confs ],
      editables => { map { $_->[0] => 1 } @confs }
    };
  }
  
  my $columns = $self->columns;
  
  return ($columns, $rows, $json) if $record_ids;
  return $self->records_html($columns, $rows, $json) . '<p><a href="#" class="create_set">Create a new configuration set</a></p>';
}

sub records_tables {
  my ($self, $columns, $rows) = @_;
  
  return $self->SUPER::records_tables($columns, $rows, {
    user      => 'Your configuration sets',
    group     => 'Configuration sets from your groups',
    suggested => 'Suggested configuration sets',
  });
}

sub templates {
  return $_[0]{'templates'} ||= {
    %{$_[0]->SUPER::templates},
    conf_list => '<div class="none%s">There are no configurations in this set</div><div class="height_wrap%s"><ul class="configs editables_list val">%s</ul></div>',
    list      => '<li class="%s"><span class="name">%s</span> <b class="ellipsis">...</b><span class="conf">%s</span></li>',
  };
}

sub row {
  my ($self, $record, $confs) = @_;
  my $templates = $self->templates;
  
  return $self->SUPER::row($record, {
    confs => { value => sprintf($templates->{'conf_list'}, @$confs ? ('', '') : (' show', ' hidden'), join '', map sprintf($templates->{'list'}, @$_), sort { $a->[2] cmp $b->[2] } @$confs), class => 'wrap' },
  }, [
    'Use this configuration set',
    '<div class="config_used">Configurations applied</div>',
    'Edit configurations'
  ]);
}

sub columns {
  return $_[0]->SUPER::columns([
    { key => 'name',  title => 'Name',           width => '20%' },
    { key => 'desc',  title => 'Description',    width => '30%' },
    { key => 'confs', title => 'Configurations', width => '45%' },
  ]);
}

sub edit_table {
  my $self = shift;
  
  return '' unless scalar keys %{$self->{'editables'}};
  
  my @rows;
  
  foreach (values %{$self->{'editables'}}) {
    my $i;
    push @rows, $self->edit_table_row($_, { map { ($i++ ? 'conf' : 'type') => $_ } split ' - ', $_->{'conf_name'} }) if $_->{'conf_name'};
  }
  
  return $self->edit_table_html([
    { key => 'type', title => 'Type',          width => '15%' },
    { key => 'conf', title => 'Configuration', width => '20%' },
    { key => 'name', title => 'Name',          width => '30%' },
    { key => 'desc', title => 'Description',   width => '30%' },
  ], \@rows);
}

sub edit_table_html {
  my ($self, $columns, $rows) = @_;
  
  return join('',
    '<h1 class="add_header">Create a new set</h1>',
    $self->SUPER::edit_table_html($columns, $rows),
    $self->new_set_form
  )
}

sub new_set_form {
  my $self     = shift;
  my $hub      = $self->hub;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyConfig', function => 'add_set' }), method => 'post', class => 'add_set' });
  my $fieldset = $form->add_fieldset;
  
  if ($hub->user) {
    $fieldset->add_field({
      wrapper_class => 'save_to',
      type          => 'Radiolist',
      name          => 'record_type',
      class         => 'record_type',
      label         => 'Save to:',
      values        => [{ value => 'user', caption => 'Account' }, { value => 'session', caption => 'Session' }],
      value         => 'user',
      label_first   => 1,
    });
  } else {
    $fieldset->append_child('input', { type => 'hidden', name => 'record_type', value => 'session' });
  }
  
  $fieldset->add_field({ type => 'String', name => 'name',        label => 'Configuration set name', required => 1, maxlength => 255 });
  $fieldset->add_field({ type => 'Text',   name => 'description', label => 'Configuration set description'                           });
  
  $fieldset->append_child('input', { type => 'checkbox', value => $_,     class => "selected hidden $_", name => 'record_id' }) for keys %{$self->{'editables'}};
  $fieldset->append_child('input', { type => 'submit',   value => 'Save', class => 'save fbutton'                            });
  
  return $form->render;
}

1;