(function() {
    $.jqplot(
        'jqPlot-sample',
        data,
        {
            seriesColors: [ 'red' ],
            axes: {
                xaxis: {
                    ticks: xticks,
                    tickOptions: {
                        formatString: '%d',
                    },
                    label: xlabel
                },
                yaxis: {
                    ticks: yticks,
                    tickOptions: {
                        formatString: '%d',
                    },
                    label: ylabel
                }
            },
            seriesDefaults: {
                showLine: false,
                markerOptions: {
                    size: 6,
                    shadow: false,
                },
            },
            series: [],
            legend: {
                show: true,
                placement: 'outside',
                location: 'ne',
            },
            grid: {
                borderWidth: 0.5,
                shadow: false,
            }
        }
    );
})();
