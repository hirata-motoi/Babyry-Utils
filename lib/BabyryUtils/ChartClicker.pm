package BabyryUtils::ChartClicker;
use strict;
use warnings;
use utf8;

use YAML;
use Chart::Clicker;
use Chart::Clicker::Context;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Series;
use Geometry::Primitive::Rectangle;
use Graphics::Color::RGB;
use Geometry::Primitive::Circle;

sub write_chart {
    my ($self, $datasets, $opts) = @_;

    $cc->border->width(0);
    $cc->background_color(
        Graphics::Color::RGB->new(red => .95, green => .94, blue => .92)
    );
    my $grey = Graphics::Color::RGB->new(
        red => .36, green => .36, blue => .36, alpha => 1
    );
    my $moregrey = Graphics::Color::RGB->new(
        red => .71, green => .71, blue => .71, alpha => 1
    );
    my $orange = Graphics::Color::RGB->new(
        red => .88, green => .48, blue => .09, alpha => 1
    );
    my @colors = splice ($grey, $moregrey, $orange), 0, scalar(@$datasets);
    $cc->color_allocator->colors(\@colors);

    $cc->plot->grid->background_color->alpha(0);
    my $ds = Chart::Clicker::Data::DataSet->new(series => $datasets);
    $cc->add_to_datasets($ds);
    my $defctx = $cc->get_context('default');
    $defctx->range_axis->label($opts->{y_label} || 'y');
    $defctx->domain_axis->label($opts->{x_label} || 'x');
    # $defctx->range_axis->brush->width(0);
    $defctx->domain_axis->tick_label_angle(0.785398163);
    $defctx->range_axis->fudge_amount(.05);
    $defctx->domain_axis->fudge_amount(.05);
    $defctx->range_axis->label_font->family('Hoefler Text');
    $defctx->range_axis->tick_font->family('Gentium');
    $defctx->domain_axis->tick_font->family('Gentium');
    $defctx->domain_axis->label_font->family('Hoefler Text');
    # $defctx->range_axis->show_ticks(0);
    $defctx->renderer->shape(
        Geometry::Primitive::Circle->new({
            radius => 5,
        })
    );
    $defctx->renderer->shape_brush(
        Graphics::Primitive::Brush->new(
            width => 2,
            color => Graphics::Color::RGB->new(red => .95, green => .94, blue => .92)
        )
    );
    # $defctx->renderer->additive(1);
    $defctx->renderer->brush->width(2);
    $cc->legend->font->family('Hoefler Text');
    $cc->draw;
    $cc->write($opts->{output_file})
}


1;

