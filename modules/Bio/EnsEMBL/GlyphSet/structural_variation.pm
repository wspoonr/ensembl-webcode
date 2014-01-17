package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Structural variations"; }

sub features {
  my ($self) = @_; 
  my $slice = $self->{'container'};
  my $Config = $self->{'config'};
  my $type = $self->check();
  my $source = $self->{'my_config'}->key;
  $source =~s/variation_feature_structural//;
  $source =~s/^_//;

  my $var_features;
  if ($source =~/^\w/){
    $var_features  = $slice->get_all_StructuralVariations($source);
  } else {
    $var_features  = $slice->get_all_StructuralVariations();
  }
  return $var_features;  
}


sub colour_key  {
  my ($self, $f) = @_;
  return $f->source;
}

sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($f->source);
  my @result = ();
  push @result, {
  'style'   => 'fg_ends',
  'colour'  => $colour,
  'start'   => $f->bound_start,
  'end'     => $f->bound_end
  };

  return @result;
} 

sub href {
  my ($self, $f) = @_;
  my $href = $self->_url
  ({
    'species' =>  $self->species,
    'action'  => 'StructuralVariation',
    'vid'     => $f->dbID,
    'vf'      => $f->variation_name,
    'vdb'     => 'variation'
  });
  return $href;
}

sub title {
  my ($self, $f) = @_;
  my $id = $f->variation_name;
  my $start = ($self->{'container'}->start + $f->start) -1;
  my $end = ($self->{'container'}->end + $f->end) ;
  my $pos = 'Chr ' .$f->seq_region_name .":". $start ."-" . $end;
  my $source = $f->source;

  return "Structural variation: $id; Source: $source; Location: $pos" ;
}

1;
