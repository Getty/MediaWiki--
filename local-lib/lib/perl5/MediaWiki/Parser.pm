package MediaWiki::Parser;

use strict;
use warnings;

use base qw( Parser::MGC );

## Extend the notion of an identifier to cover the values allowed by
## MediaWiki, specifically "Other characters may be ASCII letters,
## digits, hyphen, comma, period, apostrophe, parentheses and
## colon. No other ASCII characters are allowed, and will be deleted
## if found (they will probably cause a browser to misinterpret the
## URL)" - http://www.mediawiki.org/wiki/Manual:Title.php#Article_name

use constant
    pattern_ident => qr{[[:alpha:]\/\-\,\.\'\(\)\:]+\w*};

our $debug = 0;

=head1 NAME

C<MediaWiki::Parser> - A MediaWiki page (mostly template) parser

=head1 DESCRIPTION

This is a L<Parser::MGC> based MediaWiki page (mostly template) parser
to pull appart a MediaWiki formatted wiki text and build a Perl object
representation of the templates, fields and values within the page.

The main reason for using Parser::MGC is so we can handle recursive
templates, i.e. templates who are passed templates.

=cut

sub parse {
    my $self = shift;
    $self->debug('parse');
    
    ## A wiki page is defined a 'sequence of' the following options
    my $sequence =
	$self->sequence_of( sub {
	    $self->
		any_of(
		    
		    ## Templates
		    sub { $self->scope_of( '{{', \&template, '}}' ) },
		    
		    ## Currently anything else is just 'wikitext'
		    sub { $self->wikitext },
		);
        });
    
    return $self->
	make_page(
	    elements => $sequence,
	);
}

sub wikitext {
    my $self = shift;
    $self->debug('wikitex');
    
    ## Everything from where we are to the next template or EOS
    my $text =
	$self->substring_before( '{{' );
    
    ## This would keep returning '' until the end of time, so...
    length $text or $self->fail;
    
    return $text;
}

sub template {
    my $self = shift;
    $self->debug('templat');
    
    # The title of the template
    my $title = $self->title;
    
    ## The fields of the template, the optional
    ## '[key =] value' parts, '|' separated
    
    $self->maybe( sub { $self->expect( '|' ) } );
    
    my $fields = $self->
        list_of( '|', sub{ $self->fields } );
    
    return $self->
	make_template(
	    title  => $title,
	    fields => $fields,
	);
}

sub title {
    my $self = shift;
    $self->debug('title');
    
    my $title = $self->
        sequence_of( sub { $self->token_ident } );
    
    return join( ' ', @$title );
}

sub fields {
    my $self = shift;
    $self->debug('fields');
    
    $self->
        any_of(
            sub { $self->key_value },
            sub { $self->value }
        );
}

sub key_value {
    my $self = shift;
    $self->debug('key_val');
    
    # A key should be just like a 'title'
    my $key = $self->title;
    
    # If we fail here, we will fall back to 'value'
    $self->expect( '=' );
    
    ## If we got here, we just need to suck up the 'value'
    my $val = $self->value;
    
    return {
        'key'   => $key,
        'value' => $val->{value}
    };
}

sub value {
    my $self = shift;
    $self->debug('value');
    
    my $value = $self->
        sequence_of( sub {
            $self->any_of(
                ## A nested template?
                sub { $self->scope_of( '{{', \&template, '}}' ) },
                
                ## Anything else
                sub { $self->toke },
                
                )
        });
    
    return { 'value' => $value }
}

sub toke {
    my $self = shift;
    $self->debug('toke');
    
    my $toke = $self->
        substring_before( qr/}}|{{|\|/ );
    
    ## This would keep returning '' until the end of time, so...
    length $toke or $self->fail;
    
    return $toke;
}

sub debug {
    my $self = shift;
    my $subr = shift || 'unk';
    
    my ( $lineno, $col, $text ) = $self->where;
    
    print join("\t", $subr, $lineno, $col, $text), "\n"
        if $debug > 0;
}



## See Tangence::Compiler::Parser

=head2 $page = $parser->make_page( %args )

Return a new instance of L<MediaWiki::Page>

=cut

sub make_page
{
   shift;
   require MediaWiki::Page;
   return MediaWiki::Page->new( @_ );
}


=head2 $template = $parser->make_template( %args )

Return a new instance of L<MediaWiki::Template>

=cut

sub make_template
{
   shift;
   require MediaWiki::Template;
   return MediaWiki::Template->new( @_ );
}


1;