App.StonehearthSelectRosterView = App.View.extend({
    templateName: 'stonehearthSelectRoster',
    i18nNamespace: 'stonehearth',
    classNames: ['flex', 'fullScreen', 'newGameFlowBackground'],
    // Game options (such as peaceful mode, etc.)
    _options: {},
    _components: {
        'citizens': {
            '*': {
                'stonehearth:unit_info': {},
                'stonehearth:attributes': {
                    'attributes': {}
                },
            }
        }
    },

    citizenLockedOptions: [],

    init: function () {
        this._super();
        var self = this;
        self._citizensArray = [];
        self._analytics = {
            'game_id': null,
            'total_roster_rerolls': 0,
            'individual_roster_rerolls': 0,
            'appearance_roster_rerolls': 0,
            'total_roster_time': 0
        };
    },

    didInsertElement: function () {
        this._super();
        var self = this;
        self._start = Date.now();

        self.$('#acceptRosterButton').click(function () {
            if (self._citizensArray.length > 0) {
                self._setTotalTime();
                self._embark();
            }
        });

        self.$('.lockAllButton').tooltipster();

        self.createLockTooltip(self.$('.nameLock.lockImg'), 'name');
        self.createLockTooltip(self.$('#customizeButtons .lockImg'), 'appearance');

        self._generate_citizens(true);
        self.set('selectedViewIndex', 0);

        self._nameInput = new StonehearthInputHelper(self.$('.name'), function (value) {
            radiant.call('stonehearth:set_custom_name', self.get('selected').__self, value);
            var selectedView = self.get('selectedView');
            selectedView.setNameLocked(true);
        });
    },

    willDestroyElement: function () {
        this.$().find('.tooltipstered').tooltipster('destroy');
        this.$().off('click', '#acceptRosterButton');
    },

    destroy: function () {
        if (this._nameInput) {
            this._nameInput.destroy();
            this._nameInput = null;
        }
        this._super();
    },

    incrementAppearanceRerolls: function () {
        this._analytics.appearance_roster_rerolls += 1;
    },

    incrementIndividualRerolls: function () {
        this._analytics.individual_roster_rerolls += 1;
    },

    _incrementTotalRerolls: function () {
        this._analytics.total_roster_rerolls += 1;
    },

    _setTotalTime: function () {
        this._analytics.total_roster_time = (Date.now() - this._start) / 1000;
    },

    actions: {
        regenerateCitizens: function () {
            var self = this;
            if (self.$('#rerollCitizensText').hasClass('disabled')) {
                return;
            }

            self._resetSelected();
            self._generate_citizens(false);
        },

        quitToMainMenu: function () {
            App.stonehearthClient.quitToMainMenu('shellView');
        }
    },

    setSelectedCitizen: function (citizen, selectedView, selectedViewIndex) {
        var self = this;
        var existingSelected = self.get('selected');
        if (citizen) {
            var uri = citizen.__self;
            self.set('selected', citizen);
            self.set('selectedView', selectedView);
            self.set('selectedViewIndex', selectedViewIndex)
        }
    },

    setCitizenLockedOptions: function (rosterEntryIndex, options) {
        this.citizenLockedOptions[rosterEntryIndex] = options;
    },

    createLockTooltip: function (element, descriptionKey) {
        var lockTooltipStr = 'stonehearth:ui.data.tooltips.customization_lock.description';
        var selectRosterStr = 'stonehearth:ui.shell.select_roster.';

        element.tooltipster({
            content: i18n.t(lockTooltipStr, {
                customization: i18n.t(selectRosterStr + descriptionKey)
            })
        });
    },

    _generate_citizens: function (initialize) {
        var self = this;

        if (!initialize) {
            radiant.call('radiant:play_sound', {
                'track': 'stonehearth:sounds:ui:start_menu:reroll'
            });
        }

        self.$('#rerollCitizensText').addClass('disabled');

        radiant.call_obj('stonehearth.game_creation', 'generate_citizens_command', initialize, self.citizenLockedOptions)
            .done(function (e) {
                if (!initialize) {
                    self._incrementTotalRerolls();
                }

                var citizenMap = e.citizens;
                self.$('#rerollCitizensText').removeClass('disabled');
                self._citizensArray = radiant.map_to_array(citizenMap);
                self.set('citizensArray', self._citizensArray);
            })
            .fail(function (e) {
                console.error('generate_citizens failed:', e)
            });
    },

    _embark: function () {
        var self = this;
        radiant.call('radiant:play_sound', {
            'track': 'stonehearth:sounds:ui:start_menu:embark'
        });
        App.navigate('shell/loadout', {
            _options: self._options,
            _analytics: self._analytics
        });
        self.destroy();
    },

    _resetSelected: function () {
        var self = this;
        self.set('selectedView', null);
        self.set('selected', null);
    }
});

// view for an individual roster entity
App.StonehearthCitizenRosterEntryView = App.View.extend({
    tagName: 'div',
    classNames: ['rosterEntry'],
    templateName: 'citizenRosterEntry',
    uriProperty: 'model',

    components: {
        'stonehearth:unit_info': {},
        'stonehearth:attributes': {},
        'stonehearth:traits': {
            'traits': {
                '*': {}
            }
        },
        'render_info': {}
    },

    init: function () {
        this.set('lockedOptions', null);
        this._portraitId = 0;
        this._super();
    },

    didInsertElement: function () {
        this._super();
        var self = this;

        var lockTooltipStr = 'stonehearth:ui.data.tooltips.customization_lock.description';
        var selectRosterStr = 'stonehearth:ui.shell.select_roster.';

        self._viewIndex = self.get('index');
        var existingLockedOptions = self.rosterView.citizenLockedOptions[self._viewIndex];
        if (existingLockedOptions) {
            self.set('lockedOptions', existingLockedOptions);
        }

        self._update();
        self._genders = App.constants.population.genders;
        self._default_gender = App.constants.population.DEFAULT_GENDER;
        var editName = this.$().find('.name');
        self._nameInput = new StonehearthInputHelper(editName, function (value) {
            radiant.call('stonehearth:set_custom_name', self._citizenObjectId, value);
            self.setNameLocked(true);
        });

        Ember.run.scheduleOnce('afterRender', self, '_updateStatTooltips');
    },

    willDestroyElement: function () {
        this.$().find('.tooltipstered').tooltipster('destroy');
        if (this._nameInput) {
            this._nameInput.destroy();
            this._nameInput = null;
        }
        this._super();
    },

    click: function (e) {
        var self = this;
        if (!e.target || !$(e.target).hasClass('rerollCitizenDice')) {
            radiant.call('radiant:play_sound', {
                'track': 'stonehearth:sounds:ui:action_click'
            });
            self._selectRow(true);
        }
    },

    actions: {
        regenerateCitizenStatsAndAppearance: function () {
            var self = this;
            if (self.$('.rerollCitizenDice').hasClass('disabled')) {
                return;
            }

            radiant.call('radiant:play_sound', {
                'track': 'stonehearth:sounds:ui:start_menu:reroll'
            });

            self.$('.rerollCitizenDice').addClass('disabled');
            var lockedOptions = self._getLockedOptions();

            radiant.call_obj('stonehearth.game_creation', 'regenerate_citizen_stats_and_appearance_command', self._viewIndex, lockedOptions)
                .done(function (e) {
                    self.set('uri', e.citizen);

                    // if same uri, select row and update view now, since we don't need to wait for model to be updated
                    if (self._citizenObjectId == e.citizen) {
                        self._selectRow();
                        self._updateCitizenView(e.citizen);
                    } else {
                        self.$().addClass('regenerated');
                    }
                    self.$('.rerollCitizenDice').removeClass('disabled');
                    self.rosterView.incrementIndividualRerolls();
                })
                .fail(function (e) {
                    console.error('regenerate citizen failed:', e)
                });
        },

        regenerateCitizenAppearance: function () {
            var self = this;
            if (self.$('#rerollAppearanceDice').hasClass('disabled')) {
                return;
            }

            radiant.call('radiant:play_sound', {
                'track': 'stonehearth:sounds:ui:start_menu:reroll'
            });

            self.$('#rerollAppearanceDice').addClass('disabled');

            radiant.call_obj('stonehearth.customization', 'regenerate_appearance_command', self._citizenObjectId, self._getLockedCustomizations())
                .done(function (e) {
                    self._updateCitizenView(self._citizenObjectId);
                    self.rosterView.incrementAppearanceRerolls();
                    self.$('#rerollAppearanceDice').removeClass('disabled');
                })
                .fail(function (e) {
                    console.error('regenerate citizen appearance failed:', e)
                });
        },

        setGender: function (targetGender) {
            var self = this;
            var currentGender = self._getCurrentGender();
            if (currentGender == targetGender) {
                return;
            }

            radiant.call('radiant:play_sound', {
                'track': 'stonehearth:sounds:ui:action_click'
            });

            radiant.call_obj('stonehearth.game_creation', 'change_gender_command', self._viewIndex, targetGender)
                .done(function (e) {
                    self.set('uri', e.citizen);
                    self.$().addClass('regenerated');
                    Ember.run.scheduleOnce('afterRender', self, function () {
                        self._updateGenderTooltips(targetGender);
                    });
                })
                .fail(function (e) {
                    console.error('change genders command failed:', e)
                });
        },
        changeIndex: function (operator, customizeType) {
            var self = this;
            if (self.rosterView.$('#customizeButtons').find('.arrowButton').hasClass('selected')) {
                return;
            }

            self.setCustomizationLocked(customizeType, true);
            self._changeCustomization(operator, customizeType);
        },

        toggleLock: function (type, customizeType) {
            var self = this;
            if (type == 'name') {
                var existing = self.get('nameLocked');
                self.setNameLocked(!existing);
            } else if (type == 'customization') {
                var locked = self._isCustomizationLocked(customizeType);
                self.setCustomizationLocked(customizeType, !locked);
            } else {
                console.log('unrecognized argument to toggleLock');
            }
        },

        unlockAllOptions: function () {
            var self = this;
            self.set('lockedOptions', null);
        },

        lockAllOptions: function () {
            var self = this;
            self.setNameLocked(true);
            self.setCustomizationLocked('head_hair', true);
            self.setCustomizationLocked('face_hair', true);
            self.setCustomizationLocked('hair_color', true);
            self.setCustomizationLocked('skin_color', true);
            self.setCustomizationLocked('eye_color', true);
            self.setCustomizationLocked('head_accessory', true);
        }
    },

    setCustomizationHidden: function (customizeType, bool) {
        var hiddenCustomizations = this.get('hiddenCustomizations') || {};
        hiddenCustomizations[customizeType] = bool;
        this.set('hiddenCustomizations', hiddenCustomizations);
        this.notifyPropertyChange('hiddenCustomizations');
    },

    setCustomizationLocked: function (customizeType, bool) {
        var lockedOptions = this.get('lockedOptions') || {};
        if (!lockedOptions.customizations) {
            lockedOptions.customizations = {};
        }
        lockedOptions.customizations[customizeType] = bool;
        this.set('lockedOptions', lockedOptions);
        this.notifyPropertyChange('lockedOptions');
    },

    setNameLocked: function (bool) {
        var lockedOptions = this.get('lockedOptions') || {};
        lockedOptions.name = bool;
        this.set('lockedOptions', lockedOptions);
        this.notifyPropertyChange('lockedOptions');
    },

    _getLockedOptions: function () {
        if (this.get('anyOptionLocked')) {
            return this.get('lockedOptions');
        }
    },

    _updateCustomizationIndices: function (citizen) {
        var self = this;
        radiant.call_obj('stonehearth.customization', 'get_and_update_customization_indices_command', citizen)
            .done(function (response) {
                if (self.isDestroyed || self.isDestroying) {
                    return;
                }
                self.set('styleIndices', response.category_indices);
                self.set('styleIndexMap', response.index_map);
                radiant.each(response.index_map, function (category, _) {
                    var index = response.category_indices[category];
                    self._updateCustomizationButton(category, index);
                });
            });
    },

    _updateCustomizationButton: function (category, index) {
        var self = this;
        // hide button for this category if we have no options for it
        var hide = !index;
        self.setCustomizationHidden(category, hide);
        // update index displayed on button
        self.set(category + '_index', index);
    },

    _changeCustomization: function (operator, customizeType) {
        var self = this;
        var styleIndices = self.get('styleIndices');
        var styleIndexMap = self.get('styleIndexMap');

        if (styleIndices && styleIndexMap) {
            var currentIndex = styleIndices[customizeType];
            var data = styleIndexMap[customizeType];

            if (!currentIndex || !data) {
                return; // entity has no options for this customization type
            }

            if (data.length) {
                var newIndex = self._getNextIndex(currentIndex, data.length, operator);

                self.rosterView.$('#customizeButtons').find('.arrowButton').addClass('selected');
                radiant.call_obj('stonehearth.customization', 'change_customization_command', self._citizenObjectId, customizeType, newIndex)
                    .done(function (response) {
                        // update style indices and index
                        var currentIndices = self.get('styleIndices');
                        currentIndices[customizeType] = newIndex;
                        self.set(customizeType + '_index', newIndex);
                        self.rosterView.$('#customizeButtons').find('.arrowButton').removeClass('selected');
                        self._updatePortrait();
                    })
                    .fail(function (response) {
                        console.log('change_customization_command failed. ' + response);
                    });
            }
        }
    },

    _getNextIndex: function (index, max, operator) {
        var newIndex;
        if (operator == 'increment') {
            newIndex = (index % max) + 1; // 1-based indexing for lua
        } else if (operator == 'decrement') {
            if (index - 1 <= 0) {
                newIndex = max;
            } else {
                newIndex = (index + max - 1) % max;
            }
        } else {
            console.log('invalid operator ' + operator);
        }

        return newIndex;
    },

    _updatePortrait: function () {
        var self = this;
        // add a dummy parameter portraitId so ember will rerender the portrait even if the entity stays the same (their appearance may have changed)
        self.set('portrait', '/r/get_portrait/?type=bodyshot&animation=emote_wave.json&time=40&entity=' + self._citizenObjectId + '&portraitId=' + self._portraitId);
        self._portraitId += 1;
    },

    _updateStatTooltips: function () {
        var self = this;

        self.$('.stat').each(function () {
            var attrib_name = $(this).attr('id');
            var tooltipString = App.tooltipHelper.getTooltip(attrib_name);
            $(this).tooltipster({
                content: $(tooltipString)
            });
        });
    },

    _updateGenderTooltips: function (currentGender) {
        var self = this;
        if (!currentGender) {
            currentGender = self._getCurrentGender();
        }

        $('#genderButtons').find('.tooltipstered').tooltipster('destroy');

        radiant.each(self._genders, function (_, genderName) {
            var element = self.rosterView.$('#' + genderName);
            var tooltipKey;
            if (genderName == currentGender) {
                tooltipKey = 'current_gender';
            } else {
                tooltipKey = 'change_gender';
            }

            var genderString = i18n.t('stonehearth:ui.game.entities.gender.' + genderName);
            var tooltipString = App.tooltipHelper.getTooltip(tooltipKey, null, null, {
                gender: genderString
            });
            $(element).tooltipster({
                content: $(tooltipString)
            });
        });
    },

    _getCurrentGender: function () {
        return this.get('model.render_info.model_variant') || this._default_gender;
    },

    _onLockedOptionsChanged: function () {
        var self = this;
        var lockedOptions = self._getLockedOptions();
        self.rosterView.setCitizenLockedOptions(self._viewIndex, lockedOptions);

        // update lock tooltip based on whether name and/or appearance have been locked
        if (lockedOptions) {
            self.$().find('.lockImg.tooltipstered').tooltipster('destroy');
            var nameLocked = self._isNameLocked();
            var customizationLocked = self._isAnyCustomizationLocked();
            var tooltipKey = '';
            if (nameLocked && customizationLocked) {
                tooltipKey = 'name_and_appearance';
            } else if (nameLocked) {
                tooltipKey = 'name';
            } else if (customizationLocked) {
                tooltipKey = 'appearance';
            }

            self.rosterView.createLockTooltip(self.$('.lockImg'), tooltipKey);
        }
    }.observes('lockedOptions'),

    _onNameChanged: function () {
        var unit_name = i18n.t(this.get('model.stonehearth:unit_info.display_name'), {
            self: this.get('model')
        });
        this.set('model.unit_name', unit_name);
    }.observes('model.stonehearth:unit_info'),

    _selectRow: function () {
        var self = this;
        var selected = self.$().hasClass('selected'); // Is this row already selected?
        if (!selected) {
            self.rosterView.$('.rosterEntry').removeClass('selected'); // Unselect everything in the parent view
            self.$().addClass('selected');
        }

        self.rosterView.setSelectedCitizen(self.get('model'), self, self._viewIndex);
        Ember.run.scheduleOnce('afterRender', self, '_updateGenderTooltips');
    },

    _update: function () {
        var self = this;
        var citizenData = self.get('model');
        if (self.$() && citizenData) {
            self._citizenObjectId = citizenData.__self;
            self._updateCitizenView(self._citizenObjectId);
            if (self.$().hasClass('regenerated')) {
                self.$().removeClass('regenerated');
                self._selectRow();
            } else if (!self.$().hasClass('selected')) {
                if (self._viewIndex == self.rosterView.get('selectedViewIndex')) {
                    self._selectRow();
                }
            }
        }
    }.observes('model'),

    _updateCitizenView: function (citizen) {
        var self = this;

        if (citizen) {
            self._updatePortrait();
            self._updateCustomizationIndices(citizen);
        }
    },

    _buildTraitsArray: function () {
        var traits = [];
        var traitMap = this.get('model.stonehearth:traits.traits');

        if (traitMap) {
            traits = radiant.map_to_array(traitMap);
            traits.sort(function (a, b) {
                var aUri = a.uri;
                var bUri = b.uri;
                var n = aUri.localeCompare(bUri);
                return n;
            });
        }

        this.set('traits', traits);
    }.observes('model.stonehearth:traits'),

    _isCustomizationLocked: function (customizeType) {
        return this._getLockedCustomizations()[customizeType];
    },

    _isNameLocked: function () {
        var lockedOptions = this.get('lockedOptions');
        return lockedOptions && lockedOptions.name;
    },

    _isAnyCustomizationLocked: function () {
        var self = this;
        var lockedCustomizations = self._getLockedCustomizations();
        var hasLockedCustomization = false;
        radiant.each(lockedCustomizations, function (customizeType, isLocked) {
            if (isLocked) {
                // only counts as locked if customization type is not hidden
                if (!self._isCustomizationHidden(customizeType)) {
                    hasLockedCustomization = true;
                    return false;
                }
            }
        });

        return hasLockedCustomization;
    },

    _isCustomizationHidden: function (customizeType) {
        var hidden = this.get('hiddenCustomizations');
        return hidden && hidden[customizeType];
    },

    _getLockedCustomizations: function () {
        var lockedOptions = this.get('lockedOptions');
        return (lockedOptions && lockedOptions.customizations) || {};
    },

    // properties that control gender, and customization locking / hiding
    male: function () {
        var gender = this._getCurrentGender();
        if (gender == this._genders.male) {
            return 'selected';
        };
    }.property('model.render_info'),

    female: function () {
        var gender = this._getCurrentGender();
        if (gender == this._genders.female) {
            return 'selected';
        };
    }.property('model.render_info'),

    hairStyleLocked: function () {
        var self = this;
        if (self._isCustomizationHidden('head_hair')) {
            return 'hidden';
        }

        if (self._isCustomizationLocked('head_hair')) {
            return 'locked';
        }
    }.property('hiddenCustomizations', 'lockedOptions'),

    faceHairLocked: function () {
        var self = this;
        if (self._isCustomizationHidden('face_hair')) {
            return 'hidden';
        }

        if (self._isCustomizationLocked('face_hair')) {
            return 'locked';
        }
    }.property('hiddenCustomizations', 'lockedOptions'),

    skinColorLocked: function () {
        var self = this;
        if (self._isCustomizationHidden('skin_color')) {
            return 'hidden';
        }

        if (self._isCustomizationLocked('skin_color')) {
            return 'locked';
        }
    }.property('hiddenCustomizations', 'lockedOptions'),

    hairColorLocked: function () {
        var self = this;
        if (self._isCustomizationHidden('hair_color')) {
            return 'hidden';
        }

        if (self._isCustomizationLocked('hair_color')) {
            return 'locked';
        }
    }.property('hiddenCustomizations', 'lockedOptions'),

    eyeColorLocked: function () {
        var self = this;
        if (self._isCustomizationHidden('eye_color')) {
            return 'hidden';
        }

        if (self._isCustomizationLocked('eye_color')) {
            return 'locked';
        }
    }.property('hiddenCustomizations', 'lockedOptions'),

    accessoryLocked: function () {
        var self = this;
        if (self._isCustomizationLocked('head_accessory')) {
            return 'locked';
        }
    }.property('lockedOptions'),

    nameLocked: function () {
        return this._isNameLocked();
    }.property('lockedOptions'),

    // check if any options are locked (name, appearance customizations)
    anyOptionLocked: function () {
        var self = this;
        var lockedOptions = self.get('lockedOptions');
        if (lockedOptions) {
            if (self._isNameLocked()) {
                return true;
            }

            if (self._isAnyCustomizationLocked()) {
                return true;
            }
        }

        return false;
    }.property('hiddenCustomizations', 'lockedOptions'),

    allOptionsLocked: function () {
        return this.get('nameLocked') &&
            this.get('hairStyleLocked') &&
            this.get('faceHairLocked') &&
            this.get('skinColorLocked') &&
            this.get('hairColorLocked') &&
            this.get('eyeColorLocked') &&
            this.get('accessoryLocked');
    }.property('hiddenCustomizations', 'lockedOptions')

});
