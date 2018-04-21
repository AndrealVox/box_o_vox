$.widget("stonehearth.stonehearthMap", $('#map').stonhearthMap, {
    options: {
        // callbacks
        hover: null,
        cellSize: 12,
        settlementRadius: 9,
        click: function (cellX, cellY) {
            console.log('Selected cell: ' + cellX + ', ' + cellY);
        }
    },

    oldPalette: {
        water: '#133448',
        plains_1: '#927e59',
        plains_2: '#948a48',
        foothills_1: '#888a4a',
        foothills_2: '#888a4a',
        foothills_3: '#888a4a',
        mountains_1: '#807664',
        mountains_2: '#888071',
        mountains_3: '#948d7f',
        mountains_4: '#aaa59b',
        mountains_5: '#c5c0b5',
        mountains_6: '#d9d5cb',
        mountains_7: '#f2eee3',
        mountains_8: '#f2eee3'
    }
});
