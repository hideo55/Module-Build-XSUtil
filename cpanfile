requires 'perl' => '5.008005';
requires 'parent' => '0',
requires 'Exporter' => '0',
requires 'Devel::PPPort' => 3.19,
requires 'XSLoader' => 0.02,
requires 'ExtUtils::ParseXS' => '2.21',
requires 'Devel::CheckLib' => 0.04,
requires 'Devel::CheckCompiler' => 0.02,
requires 'ExtUtils::CBuilder';
requires 'Devel::XSHelper';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

