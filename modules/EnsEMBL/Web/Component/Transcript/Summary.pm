# $Id$

package EnsEMBL::Web::Component::Transcript::Summary;

use strict;
use warnings;
no warnings 'uninitialized';

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  return sprintf '<p>%s</p>', $object->Obj->description if $object->Obj->isa('EnsEMBL::Web::Fake');
  return '<p>This transcript is not in the current gene set</p>' unless $object->Obj->isa('Bio::EnsEMBL::Transcript');
  
  my $description = escapeHTML($object->trans_description);
  my ($edb, $acc, $html);
  
  if ($description) {
    if ($description ne 'No description') {
      if ($object->get_db eq 'vega') {
        $edb = 'Vega';
        $acc = $object->Obj->stable_id;
        $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb", $edb . '_transcript', $acc);
      } else {
        $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
        $description =~ s/\[\w+:([\w\/\_]+)\;\w+:(\w+)\]//g;
        ($edb, $acc) = ($1, $2);
        $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb $acc", $edb, $acc) if $acc ne 'content';
      }
      
      $html .= "<p>$description</p>";
    }
  }
  
  my $url = $self->object->_url({
    type   => 'Location',
    action => 'View',
    r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
  });

  my $location_html = sprintf(
    '<a href="%s">%s: %s-%s</a> %s.',
    $url,
    $object->neat_sr_name($object->seq_region_type, $object->seq_region_name),
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );

  # alternative (Vega) coordinates
  my $lc_type      = lc $object->type_name ;
  my $alt_assembly = $object->species_defs->ALTERNATIVE_ASSEMBLY;
  
  if ($alt_assembly and $object->get_db eq 'vega') {
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($object->species, 'vega')->group;
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, 'vega');
    
    my $alt_slices = $object->vega_projection($alt_assembly); # project feature slice onto Vega assembly
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l   = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      my $url = $object->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external">%s-%s</a>',
        $url,
        $object->thousandify($alt_slices->[0]->start),
        $object->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $alt_assembly coordinates</span>]";
    } else {
      $location_html .= qq{ [<span class="small">There is no ungapped mapping of this $lc_type onto the $alt_assembly assembly</span>]};
    }
  
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, $orig_group); # set dnadb back to the original group
  }

  $html .= qq{
    <dl class="summary">
      <dt>Location</dt>
      <dd>
        $location_html
      </dd>
    </dl>};

  # Now create the gene and transcript information
  my $gene = $object->gene; 
  
  if ($gene) {
    my $gene_id     = $gene->stable_id;
    my $transcripts = $gene->get_all_Transcripts;
    my $transcript  = $object->stable_id;
    my $count       = @$transcripts;
    my $plural_1    = 'are';
    my $plural_2    = 'transcripts';
    my $action      = $object->action;
    
    my $gene_url = $object->_url({
      type   => 'Gene',
      action => 'Summary',
      g      => $gene_id
    });
    
    if ($count == 1) { 
      $plural_1 = 'is';
      $plural_2 =~ s/s$//;
    }
    
    $html .= qq{
      <dl class="summary">
      <dt>Gene</dt>
      <dd>
        <p class="toggle_text" id="transcripts_text">This transcript is a product of gene <a href="$gene_url">$gene_id</a> - There $plural_1 $count $plural_2 in this gene: </p>
        <table class="toggle_table" id="transcripts" summary="List of transcripts for this gene - along with translation information and type">
        <tr>
          <th>Name</th>
          <th>Transcript ID</th>
          <th>Protein ID</th>
          <th>Description</th> 
        </tr>
    };
    
    foreach (map $_->[2], sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map {[ $_->external_name, $_->stable_id, $_ ]} @$transcripts) {
      my $protein = 'No protein product';
      
      my $url = $self->object->_url({
        action   => $action eq 'ProteinSummary' ? 'Summary' : $action,
        type     => 'Transcript',
        function => undef,
        t        => $_->stable_id
      });
      
      if ($_->translation) {
        $protein = sprintf(
          '<a href="%s">%s</a>',
          $self->object->_url({
            type   => 'Transcript',
            action => 'ProteinSummary',
            t      => $_->stable_id
          }),
          $_->translation->stable_id
        );
      }
      
      $html .= sprintf('
        <tr%s>
          <th>%s</th>
          <td><a href="%s">%s</a></td>
          <td>%s</td>
          <td>%s</td>
        </tr>',
        $_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id,
        $protein,
        $_->biotype
      );
    }
    
    $html .= '
      </table>
     </dd>
    </dl>';
    
    $html .= $self->_hint('transcript', 'Transcript and Gene level displays', sprintf('
      <p>
        In %s a gene is made up of one or more transcripts. 
        Views in Ensembl are separated into Gene based views and Transcript based views according to which level the information is more appropriately associated. 
        This view is a transcript level view. To flip between the two sets of views you can click on the Gene and Transcript tabs in the menu bar at the top of the page.
      </p>', $object->species_defs->ENSEMBL_SITETYPE
    ));
  }
  
  return $html;
}

1;
