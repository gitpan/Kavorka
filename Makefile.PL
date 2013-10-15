use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = eval( $ExtUtils::MakeMaker::VERSION );

my $meta = {
  "abstract"       => "function signatures with the lure of the animal",
  "author"         => ["Toby Inkster (TOBYINK) <tobyink\@cpan.org>"],
  "dynamic_config" => 0,
  "generated_by"   => "Dist::Inkt::Profile::TOBYINK version 0.013, CPAN::Meta::Converter version 2.120921",
  "keywords"       => [],
  "license"        => ["perl_5"],
  "meta-spec"      => {
                        url => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
                        version => 2,
                      },
  "name"           => "Kavorka",
  "no_index"       => { directory => ["eg", "examples", "inc", "t", "xt"] },
  "prereqs"        => {
                        configure => { requires => { "ExtUtils::MakeMaker" => 6.17 } },
                        develop   => { recommends => { "Dist::Inkt" => 0.001 } },
                        runtime   => {
                                       requires => {
                                         "Data::Alias"      => 0,
                                         "Devel::Pragma"    => 0,
                                         "Exporter::Tiny"   => 0.026,
                                         "Module::Runtime"  => 0,
                                         "Moo"              => 1.003001,
                                         "namespace::sweep" => 0.006,
                                         "PadWalker"        => 0,
                                         "Parse::Keyword"   => 0.06,
                                         "perl"             => 5.014,
                                         "Sub::Name"        => 0,
                                         "Type::Parser"     => 0.028,
                                         "Type::Registry"   => 0.028,
                                         "Type::Utils"      => 0.028,
                                         "Types::Standard"  => 0.028,
                                       },
                                     },
                        test      => {
                                       recommends => {
                                                       "Class::Method::Modifiers" => 2.03,
                                                       "Class::Tiny" => 0,
                                                       "Moose" => "2.0000",
                                                       "Mouse" => "1.00",
                                                       "Role::Tiny" => "1.003000",
                                                     },
                                       requires   => { "Test::Fatal" => 0, "Test::More" => 0.96, "Test::Requires" => 0 },
                                     },
                      },
  "provides"       => {
                        "Kavorka"                                   => { file => "lib/Kavorka.pm", version => 0.006 },
                        "Kavorka::MethodModifier"                   => { file => "lib/Kavorka/MethodModifier.pm", version => 0.006 },
                        "Kavorka::Multi"                            => { file => "lib/Kavorka/Multi.pm", version => 0.006 },
                        "Kavorka::Signature"                        => { file => "lib/Kavorka/Signature.pm", version => 0.006 },
                        "Kavorka::Signature::Parameter"             => { file => "lib/Kavorka/Signature/Parameter.pm", version => 0.006 },
                        "Kavorka::Sub"                              => { file => "lib/Kavorka/Sub.pm", version => 0.006 },
                        "Kavorka::Sub::After"                       => { file => "lib/Kavorka/Sub/After.pm", version => 0.006 },
                        "Kavorka::Sub::Around"                      => { file => "lib/Kavorka/Sub/Around.pm", version => 0.006 },
                        "Kavorka::Sub::Before"                      => { file => "lib/Kavorka/Sub/Before.pm", version => 0.006 },
                        "Kavorka::Sub::ClassMethod"                 => { file => "lib/Kavorka/Sub/ClassMethod.pm", version => 0.006 },
                        "Kavorka::Sub::Fun"                         => { file => "lib/Kavorka/Sub/Fun.pm", version => 0.006 },
                        "Kavorka::Sub::Method"                      => { file => "lib/Kavorka/Sub/Method.pm", version => 0.006 },
                        "Kavorka::Sub::ObjectMethod"                => { file => "lib/Kavorka/Sub/ObjectMethod.pm", version => 0.006 },
                        "MooseX::KavorkaInfo"                       => { file => "lib/MooseX/KavorkaInfo.pm", version => 0.006 },
                        "MooseX::KavorkaInfo::DummyInfo"            => { file => "lib/MooseX/KavorkaInfo.pm", version => 0 },
                        "MooseX::KavorkaInfo::Trait::Method"        => { file => "lib/MooseX/KavorkaInfo.pm", version => 0.006 },
                        "MooseX::KavorkaInfo::Trait::WrappedMethod" => { file => "lib/MooseX/KavorkaInfo.pm", version => 0.006 },
                        "Parse::KeywordX"                           => { file => "lib/Parse/KeywordX.pm", version => 0.006 },
                      },
  "release_status" => "stable",
  "resources"      => {
                        bugtracker   => { web => "http://rt.cpan.org/Dist/Display.html?Queue=Kavorka" },
                        homepage     => "https://metacpan.org/release/Kavorka",
                        license      => ["http://dev.perl.org/licenses/"],
                        repository   => { type => "git", web => "https://github.com/tobyink/p5-kavorka" },
                        X_identifier => "http://purl.org/NET/cpan-uri/dist/Kavorka/project",
                      },
  "version"        => 0.006,
};

my %dynamic_config;

my %WriteMakefileArgs = (
	ABSTRACT   => $meta->{abstract},
	AUTHOR     => ($EUMM >= 6.5702 ? $meta->{author} : $meta->{author}[0]),
	DISTNAME   => $meta->{name},
	VERSION    => $meta->{version},
	EXE_FILES  => [ map $_->{file}, values %{ $meta->{x_provides_scripts} || {} } ],
	NAME       => do { my $n = $meta->{name}; $n =~ s/-/::/g; $n },
	%dynamic_config,
);

$WriteMakefileArgs{LICENSE} = $meta->{license}[0] if $EUMM >= 6.3001;

sub deps
{
	my %r;
	for my $stage (@_)
	{
		for my $dep (keys %{$meta->{prereqs}{$stage}{requires}})
		{
			next if $dep eq 'perl';
			my $ver = $meta->{prereqs}{$stage}{requires}{$dep};
			$r{$dep} = $ver if !exists($r{$dep}) || $ver >= $r{$dep};
		}
	}
	\%r;
}

my ($build_requires, $configure_requires, $runtime_requires, $test_requires);
if ($EUMM >= 6.6303)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{TEST_REQUIRES}      ||= deps('test');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');
}
elsif ($EUMM >= 6.5503)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build', 'test');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');	
}
elsif ($EUMM >= 6.52)
{
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime', 'build', 'test');	
}
else
{
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('configure', 'build', 'test', 'runtime');	
}

{
	my ($minperl) = reverse sort(
		grep defined && /^[0-9]+(\.[0-9]+)?$/,
		map $meta->{prereqs}{$_}{requires}{perl},
		qw( configure build runtime )
	);
	
	if (defined($minperl))
	{
		die "Installing $meta->{name} requires Perl >= $minperl"
			unless $] >= $minperl;
		
		$WriteMakefileArgs{MIN_PERL_VERSION} ||= $minperl
			if $EUMM >= 6.48;
	}
}

sub FixMakefile
{
	return unless -d 'inc';
	my $file = shift;
	
	local *MAKEFILE;
	open MAKEFILE, "< $file" or die "FixMakefile: Couldn't open $file: $!; bailing out";
	my $makefile = do { local $/; <MAKEFILE> };
	close MAKEFILE or die $!;
	
	$makefile =~ s/\b(test_harness\(\$\(TEST_VERBOSE\), )/$1'inc', /;
	$makefile =~ s/( -I\$\(INST_ARCHLIB\))/ -Iinc$1/g;
	$makefile =~ s/( "-I\$\(INST_LIB\)")/ "-Iinc"$1/g;
	$makefile =~ s/^(FULLPERL = .*)/$1 "-Iinc"/m;
	$makefile =~ s/^(PERL = .*)/$1 "-Iinc"/m;
	
	open  MAKEFILE, "> $file" or die "FixMakefile: Couldn't open $file: $!; bailing out";
	print MAKEFILE $makefile or die $!;
	close MAKEFILE or die $!;
}

my $mm = WriteMakefile(%WriteMakefileArgs);
FixMakefile($mm->{FIRST_MAKEFILE} || 'Makefile');
exit(0);

