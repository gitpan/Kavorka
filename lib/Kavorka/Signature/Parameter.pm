use 5.014;
use strict;
use warnings;

package Kavorka::Signature::Parameter;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_10';

use Text::Balanced qw( extract_codeblock extract_bracketed );
use Parse::Keyword {};
use Parse::KeywordX;

use Moo;
use namespace::sweep;

has package         => (is => 'ro');
has type            => (is => 'ro');
has name            => (is => 'ro');
has constraints     => (is => 'ro', default => sub { +[] });
has named           => (is => 'ro', default => sub { 0 });
has named_names     => (is => 'ro', default => sub { +[] });

has position        => (is => 'rwp');
has default         => (is => 'ro');
has default_when    => (is => 'ro');
has ID              => (is => 'rwp');
has traits          => (is => 'ro', default => sub { +{} });

has sigil           => (is => 'lazy', builder => sub { substr(shift->name, 0, 1) });
has global          => (is => 'lazy', builder => sub { scalar(shift->name =~ /\A[\$\@\%](?:\W|_\z)/) });

sub readonly  { !!shift->traits->{ro} }
sub ro        { !!shift->traits->{ro} }
sub rw        {  !shift->traits->{ro} }
sub alias     { !!shift->traits->{alias} }
sub copy      {  !shift->traits->{alias} }
sub slurpy    { !!shift->traits->{slurpy} }
sub optional  { !!shift->traits->{optional} }
sub invocant  { !!shift->traits->{invocant} }
sub coerce    { !!shift->traits->{coerce} }
sub locked    { !!shift->traits->{locked} }

our @PARAMS;
sub BUILD
{
	my $self = shift;
	my $id = scalar(@PARAMS);
	$self->_set_ID($id);
	$PARAMS[$id] = $self;
}

my $variable_re = qr{ [\$\%\@] (?: \{\^[A-Z]+\} | \w* ) }x;

sub parse
{
	state $deparse = do { require B::Deparse; 'B::Deparse'->new };
	
	my $class = shift;
	my %args = @_;
	
	lex_read_space;
	
	my %traits = (
		invocant  => 0,
		_optional => 1,
	);
	
	if (lex_peek(6) eq 'slurpy')
	{
		lex_read(6);
		lex_read_space;
		$traits{slurpy} = 1;
	}
	
	my $type;
	my $peek = lex_peek(1000);
	if ($peek =~ /\A[^\W0-9]/)
	{
		my $reg = do {
			require Type::Registry;
			require Type::Utils;
			my $tmp = 'Type::Registry::DWIM'->new;
			$tmp->{'~~chained'} = $args{package};
			$tmp->{'~~assume'}  = 'Type::Tiny::Class';
			$tmp;
		};
		
		require Type::Parser;
		($type, my($remaining)) = Type::Parser::extract_type($peek, $reg);
		my $len = length($peek) - length($remaining);
		lex_read($len);
		lex_read_space;
	}
	elsif ($peek =~ /\A\(/)
	{
		lex_read(1);
		lex_read_space;
		my $expr = parse_listexpr;
		lex_read_space;
		lex_peek eq ')' or die "Expected ')' after type constraint expression";
		lex_read(1);
		lex_read_space;
		$type = $expr->();
		$type->isa('Type::Tiny') or die "Type constraint expression did not return a blessed type constraint object";
	}
	
	my ($named, $varname, $paramname) = 0;
	$peek = lex_peek(1000);
	
	# :foo( $foo )
	if ($peek =~ /\A(\:(\w+)\(\s*($variable_re)\s*\))/)
	{
		$named     = 1;
		$paramname = $2;
		$varname   = $3;
		lex_read(length($1));
		lex_read_space;
	}
	# :$foo
	elsif ($peek =~ /\A(\:($variable_re))/)
	{
		$named     = 1;
		$paramname = substr($2, 1);
		$varname   = $2;
		lex_read(length($1));
		lex_read_space;
	}
	# $foo
	elsif ($peek =~ /\A($variable_re)/)
	{
		$varname   = $1;
		$traits{_optional} = 0;
		lex_read(length($1));
		lex_read_space;
	}
	
	undef($peek);
	
	$traits{slurpy} = 1 if defined($varname) && $varname =~ /\A[\@\%]/;
	
	if (lex_peek eq '!')
	{
		$traits{optional} = 0;
		lex_read(1);
		lex_read_space;
	}
	elsif (lex_peek eq '?')
	{
		$traits{optional} = 1;
		lex_read(1);
		lex_read_space;
	}
	
	my (@constraints, $default, $default_when);
	
	while (lex_peek(5) eq 'where')
	{
		lex_read(1);
		lex_read_space;
		push @constraints, 'do' . $deparse->coderef2text(parse_block);
	}
	
	$peek = lex_peek(1000);
	while ($peek =~ /\A((?:is|does)\s+(\w+))/sm)
	{
		$traits{"$2"} = 1;
		lex_read(length($1));
		lex_read_space;
		$peek = lex_peek(4);
	}
	
	if ($peek =~ m{ \A ( (?: [/]{2} | [|]{2} )?= ) }x)
	{
		$default_when = $1;
		lex_read(length($1));
		lex_read_space;
		$default = parse_arithexpr;
		lex_read_space;
		$traits{_optional} = 1;
	}
	
	$traits{optional} //= $traits{_optional};
	delete($traits{_optional});
	
	return $class->new(
		%args,
		type           => $type,
		name           => $varname,
		constraints    => \@constraints,
		named          => $named,
		named_names    => [ defined($paramname) ? $paramname : () ],
		default        => $default,
		default_when   => $default_when,
		traits         => \%traits,
	);
}

sub sanity_check
{
	my $self = shift;
	
	die if $self->invocant && $self->optional;
	die if $self->invocant && $self->named;
	die if $self->invocant && $self->slurpy;
	die if $self->named && $self->slurpy;
}

sub injection
{
	my $self = shift;
	my ($sig) = @_;
	
	my $var = $self->name;
	my $is_dummy = 0;
	if (length($var) == 1)
	{
		$var .= 'tmp';
		$is_dummy = 1;
	}
	
	my ($val, $condition) = $self->_injection_extract_and_coerce_value($sig);
	
	my $code = $self->_injection_assignment($sig, $var, $val)
		. $self->_injection_conditional_type_check($sig, $condition, $var);
	
	$is_dummy ? "{ $code }" : $code;
}

sub _injection_assignment
{
	my $self = shift;
	my ($sig, $var, $val) = @_;
	
	if ($self->alias)
	{
		if ($self->global)
		{
			(my $glob = $var) =~ s/\A./*/;
			return sprintf('local %s = \\do { %s };', $glob, $val);
		}
		else
		{
			require Data::Alias;
			return sprintf('Data::Alias::alias(my %s = do { %s });', $var, $val);
		}
	}
	
	my $decl = $self->global ? 'local' : 'my';
	my $assignment = sprintf('%s %s = %s;', $decl, $var, $val);
	
	if ($self->locked)
	{
		require Hash::Util;
		require Types::Standard;
		
		state $_FIND_KEYS = sub {
			return unless $_[0];
			my ($dict) = grep {
				$_->is_parameterized
				and $_->has_parent
				and $_->parent->strictly_equals(Types::Standard::Dict())
			} $_[0], $_[0]->parents;
			return unless $dict;
			my @keys = sort keys %{ +{ @{ $dict->parameters } } };
			return unless @keys;
			\@keys;
		};
		
		my $legal_keys  = $_FIND_KEYS->($self->type);
		my $quoted_keys = $legal_keys ? join(q[,], q[], map B::perlstring($_), @$legal_keys) : '';
		my $ref_var     = $self->sigil eq '$' ? $var : "\\$var";
		
		$assignment .= "&Hash::Util::unlock_hash($ref_var);";
		$assignment .= "&Hash::Util::lock_keys($ref_var $quoted_keys);";
	}
	
	if ($self->ro)
	{
		$assignment .= sprintf(
			'&Internals::SvREADONLY(\\%s, 1);',
			$var,
		);
	}
	
	return $assignment;
}

sub _injection_conditional_type_check
{
	my $self = shift;
	my ($sig, $condition, $var) = @_;
	
	my $sigil = $self->sigil;
	my $type =
		($sigil eq '@') ? sprintf('for (%s) { %s }', $var, $self->_injection_type_check('$_')) :
		($sigil eq '%') ? sprintf('for (values %s) { %s }', $var, $self->_injection_type_check('$_')) :
		($condition eq '1')    ? sprintf('%s;', $self->_injection_type_check($var)) :
		sprintf('if (%s) { %s }', $condition, $self->_injection_type_check($var));
	
	return '' if $type =~ /\{  \}\z/;
	return $type;
}

sub _injection_extract_and_coerce_value
{
	my $self = shift;
	my ($sig) = @_;
	
	$self->coerce
		or return $self->_injection_extract_value(@_);

	my $type = $self->type
		or die("Cannot coerce without a type constraint");
	$type->has_coercion
		or die("Cannot coerce because type constraint has no coercions defined");
	
	my ($val, $condition) = $self->_injection_extract_value(@_);
	
	my $coerce_variable = sub {
		my $variable = shift;
		if ($type->coercion->can_be_inlined)
		{
			$type->coercion->inline_coercion($variable),
		}
		else
		{
			sprintf(
				'$%s::PARAMS[%d]->{type}->coerce(%s)',
				__PACKAGE__,
				$self->ID,
				$variable,
			);
		}
	};
	
	my $sigil = $self->sigil;
	
	if ($sigil eq '@')
	{
		$val = sprintf(
			'(map { %s } %s)',
			$coerce_variable->('$_'),
			$val,
		);
	}
	
	elsif ($sigil eq '%')
	{
		$val = sprintf(
			'do { my %%tmp = %s; for (values %%tmp) { %s }; %%tmp }',
			$val,
			$coerce_variable->('$_'),
		);
	}
	
	elsif ($sigil eq '$' and $type->coercion->can_be_inlined)
	{
		$val = sprintf(
			'do { my $tmp = %s; %s}',
			$val,
			$coerce_variable->('$tmp'),
		);
	}
	
	elsif ($sigil eq '$')
	{
		$val = $coerce_variable->($val);
	}
	
	wantarray ? ($val, $condition) : $val;
}

sub _injection_extract_value
{
	my $self = shift;
	my ($sig) = @_;
	
	my $condition;
	my $val;
	my $default = $self->default ? sprintf('$%s::PARAMS[%d]->{default}->()', __PACKAGE__, $self->ID) : '';
	my $slurpy_style = '';
	
	if ($self->slurpy)
	{
		if ($self->sigil eq '%'
		or ($self->sigil eq '$'
			and $self->type
			and do { require Types::Standard; $self->type->is_a_type_of(Types::Standard::HashRef()) }))
		{
			my @names = map(@{$_->named ? $_->named_names : []}, @{$sig->params});
			if (@names)
			{
				die "Cannot has aliased slurpy hash for a function with named parameters" if $self->alias;
				$val = sprintf(
					'do { use warnings FATAL => qw(all); my %%tmp = @_[ %d .. $#_ ]; delete $tmp{$_} for (%s); %%tmp ? %%tmp : (%s) }',
					$sig->last_position + 1,
					join(q[,], map B::perlstring($_), @names),
					($default // ''),
				);
			}
			else
			{
				$val = sprintf(
					'do { use warnings FATAL => qw(all); my %%tmp = @_[ %d .. $#_ ]; %%tmp ? @_[ %d .. $#_ ] : (%s) }',
					$sig->last_position + 1,
					$sig->last_position + 1,
					($default // ''),
				);
			}
			$condition = 1;
			$slurpy_style = '%';
		}
		else
		{
			die "Cannot have a slurpy array for a function with named parameters" if $sig->has_named;
			$val = sprintf(
				'($#_ >= %d) ? @_[ %d .. $#_ ] : (%s)',
				$sig->last_position + 1,
				$sig->last_position + 1,
				($default // ''),
			);
			$condition = 1;
			$slurpy_style = '@';
		}
		
		if ($self->sigil eq '$')
		{
			$val = $slurpy_style eq '%' ? "+{ $val }" : "[ $val ]";
			$slurpy_style = '$';
		}
	}
	elsif ($self->named)
	{
		my $defaultish =
			length($default) ? $default :
			$self->optional  ? 'undef'  :
			sprintf('Carp::croak(sprintf q/Named parameter `%%s` is required/, %s)', B::perlstring $self->named_names->[0]);
		
		no warnings 'uninitialized';
		my $when = +{
			'//='   => 'defined',
			'||='   => '!!',
			'='     => 'exists',
		}->{ $self->default_when } || 'exists';
		
		$val = join '', map(
			sprintf('%s($_{%s}) ? $_{%s} : ', $when, $_, $_),
			map B::perlstring($_), @{$self->named_names}
		), $defaultish;
		
		$condition = join ' or ', map(
			sprintf('%s($_{%s})', $when, $_),
			map B::perlstring($_), @{$self->named_names}
		);
	}
	elsif ($self->invocant)
	{
		my $defaultish = sprintf('Carp::croak(q/Invocant %s is required/)', $self->name);
		$val = sprintf('@_ ? shift(@_) : %s', $defaultish);
		$condition = 1;
	}
	else
	{
		my $pos        = $self->position;
		my $defaultish =
			length($default) ? $default :
			$self->optional  ? 'undef'  :
			sprintf('Carp::croak(q/Positional parameter %d is required/)', $pos);
		
		no warnings 'uninitialized';
		my $when = +{
			'//='   => 'defined($_[%d])',
			'||='   => '!!($_[%d])',
			'='     => '($#_ >= %d)',
		}->{ $self->default_when } || '($#_ >= %d)';
		
		$val = sprintf($when.' ? $_[%d] : %s', $pos, $pos, $defaultish);
		
		$condition = sprintf($when, $self->position);
	}
	
	$condition = 1 if length $default;
	
	wantarray ? ($val, $condition) : $val;
}

sub _injection_type_check
{
	my $self = shift;
	my ($var) = @_;
	
	my $check = '';
	return $check unless my $type = $self->type;
	
	my $can_xs =
		$INC{'Mouse/Util.pm'}
		&& Mouse::Util::MOUSE_XS()
		&& ($type->{_is_core} or $type->is_parameterized && $type->parent->{_is_core});
	
	if (!$can_xs and $type->can_be_inlined)
	{
		$check .= sprintf(
			'%s;',
			$type->inline_assert($var),
		);
	}
	else
	{
		$check .= sprintf(
			'$%s::PARAMS[%d]->{type}->assert_valid(%s);',
			__PACKAGE__,
			$self->ID,
			$var,
		);
	}
	
	for my $constraint (@{ $self->constraints })
	{
		$check .= sprintf(
			'do { local $_ = %s; %s } or Carp::croak(sprintf("%%s failed constraint {%%s}", %s, %s));',
			$var,
			$constraint,
			B::perlstring($var),
			B::perlstring($constraint),
		);
	}
	
	return $check;
}


1;


__END__

=pod

=encoding utf-8

=for stopwords invocant invocants lexicals unintuitive booleans globals

=head1 NAME

Kavorka::Signature::Parameter - a single parameter in a function signature

=head1 DESCRIPTION

Kavorka::Signature::Parameter is a class where each instance represents
a parameter in a function signature. This class is used to help parse
the function signature, and also to inject Perl code into the final
function.

Instances of this class are also returned by Kavorka's function
introspection API.

=head2 Introspection API

A parameter instance has the following methods:

=over

=item C<ID>

An opaque numeric identifier for this parameter.

=item C<package>

Returns the package name the parameter was declared in.

=item C<type>

A L<Type::Tiny> object representing the type constraint for the
parameter, or undef.

=item C<name>

The name of the variable associated with this parameter, including
its sigil.

=item C<constraints>

An arrayref of additional constraints upon the value. Currently these
are given as strings of Perl code, but this is subject to change.

=item C<named>

A boolean indicating whether this is a named parameter.

=item C<named_names>

An arrayref of names for this named parameter.

=item C<position>

The position for a positional parameter.

=item C<default>

A coderef supplying the default value for this parameter.

=item C<default_when>

The string "=", "//=" or "||=".

=item C<traits>

A hashref, where the keys represent names of parameter traits, and
the values are booleans.

=item C<sigil>

The sigil of the variable for this parameter.

=item C<global>

Indicates whether the variable for this parameter is a global. The
only globals supported within function signatures are C<< $_ >> and
variables named like C<< ${^XXXX} >> for any name "XXXX".

=item C<readonly>, C<ro>

A boolean indicating whether this variable will be read-only.

=item C<rw>

A boolean indicating whether this variable will be read-write.

=item C<locked>

A boolean indicating whether this variable is a locked hash(ref).

=item C<alias>

A boolean indicating whether this variable will be an alias.

=item C<copy>

A boolean indicating whether this variable will be a copy (non-alias).

=item C<slurpy>

A boolean indicating whether this variable is slurpy.

=item C<optional>

A boolean indicating whether this variable is optional.

=item C<invocant>

A boolean indicating whether this variable is an invocant.

=item C<coerce>

A boolean indicating whether this variable should coerce.

=back

=head2 Other Methods

=over

=item C<parse>

An internal method used to parse a parameter. Only makes sense to use
within a L<Parse::Keyword> parser.

=item C<injection>

The string of Perl code to inject for this parameter.

=item C<sanity_check>

Tests that the parameter is sane. (For example it would not be sane to
have an invocant that is an optional parameter.)

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<http://perlcabal.org/syn/S06.html>,
L<Kavorka>,
L<Kavorka::Signature>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

