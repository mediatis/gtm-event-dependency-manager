___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Event Dependency Manager",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Use pseudo events to trigger events dependent on other events. Example: gtm.js..extra_data.loaded",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "LABEL",
    "name": "syntax",
    "displayName": "Event syntax: dependent.event.name[..dependency.event.name]*"
  },
  {
    "type": "LABEL",
    "name": "example",
    "displayName": "Example: gtm.load..cookie_consent.loaded..country_code.loaded"
  },
  {
    "type": "TEXT",
    "name": "dependencies",
    "displayName": "Dependency events",
    "simpleValueType": true,
    "textAsList": true,
    "lineCount": 3,
    "help": "List of events that can be used as dependencies. Use wildcards \"*\" to match multiple events. Start with \"!\" to exclude events."
  },
  {
    "type": "TEXT",
    "name": "observed",
    "displayName": "Dependent events",
    "simpleValueType": true,
    "textAsList": true,
    "lineCount": 3,
    "help": "List of dependent events. Leave blank to enable all events. Use wildcards \"*\" to match multiple events. Start with \"!\" to exclude events."
  },
  {
    "type": "TEXT",
    "name": "dependencyCombinationMaximum",
    "displayName": "Dependency combination maximum",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_NEGATIVE_NUMBER"
      }
    ],
    "defaultValue": 0,
    "help": "Limits the maximum amount of dependencies that can be used in combination at once. This will limit the amount of simultaneously triggered pseudo events if many different dependencies are in play. Leave at 0 to have no limit set."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const callInWindow = require('callInWindow');
const copyFromDataLayer = require('copyFromDataLayer');
const copyFromWindow = require('copyFromWindow');
const createQueue = require('createQueue');
const dataLayerPush = createQueue('dataLayer');
const JSON = require('JSON');
const log = require('logToConsole');
const templateStorage = require('templateStorage');

const HISTORY_STORAGE_KEY = 'history';

const DATA_LAYER_KEY_EVENT_ID = 'gtm.uniqueEventId';
const DATA_LAYER_KEY_ORIGINAL_EVENT_ID = 'gtm.originalEventId';

const DATA_LAYER_KEY_MAP = {};
DATA_LAYER_KEY_MAP[DATA_LAYER_KEY_EVENT_ID] = DATA_LAYER_KEY_ORIGINAL_EVENT_ID;
DATA_LAYER_KEY_MAP['gtm.start'] = false;

// events that can be used as dependencies
const dependencies = data.dependencies;

// events that can be dependent
const observed = data.observed;

// maximum amount of dependencies in combination for pseudo events
const dependencyCombinationMaximum = data.dependencyCombinationMaximum || 0;

// short term memory about fired dependencies
// and observed events including fired pseudo events
const history = templateStorage.getItem(HISTORY_STORAGE_KEY) ? JSON.parse(templateStorage.getItem(HISTORY_STORAGE_KEY)) : {
	'dependenciesFired': [],
	'events': []
};

// compares two list of terms with each other
function termsEqual(termsA, termsB, strict) {
	if (strict) {
		// strict means that all terms must match
		// and have the same index in both term lists
		if (termsA.length !== termsB.length) {
			return false;
		}
		for (let i = 0; i < termsA.length; i++) {
			if (termsA[i] !== termsB[i]) {
				return false;
			}
		}
		return true;
	} else {
		// not strict means that all terms must
		// exist in both lists, regardless of their position
		for (let i = 0; i < termsA.length; i++) {
			if (termsB.indexOf(termsA[i]) === -1) {
				return false;
			}
		}
		for (let i = 0; i < termsB.length; i++) {
			if (termsA.indexOf(termsB[i]) === -1) {
				return false;
			}
		}
		return true;
	}
}

// tests if a set of term lists contains a specific term list
function isIn(termsSet, terms, strict) {
	for (let i = 0; i < termsSet.length; i++) {
		if (termsEqual(termsSet[i], terms, strict)) {
			return true;
		}
	}
	return false;
}

// creates a unique version of the given set of term lists
function unique(termsSet, strict) {
	const result = [];
	termsSet.forEach(terms => {
		if (!isIn(result, terms, strict)) {
			result.push(terms);
		}
	});
	return result;
}

// builds the union of two sets of term lists
function union(termsSetA, termsSetB, strict) {
	const result = [];
	termsSetA.forEach(terms => {
		result.push(terms);
	});
	termsSetB.forEach(terms => {
		result.push(terms);
	});
	return unique(result, strict);
}

// builds a list of permutations of a list of terms
function getPermutations(terms) {
	var results = [];
	function permute(arr, memo) {
		var cur;
		memo = memo || [];
		for (var i = 0; i < arr.length; i++) {
			cur = arr.splice(i, 1);
			if (arr.length === 0) {
				results.push(memo.concat(cur));
			}
			permute(arr.slice(), memo.concat(cur));
			arr.splice(i, 0, cur[0]);
		}
		return results;
	}
	return permute(terms);
}

// returns the given term list without a specific term
function without(terms, term) {
	return terms.filter(t => t !== term);
}

// builds a list of combinations of the given terms
// (without permutations)
function getCombinations(terms) {
	let result = [terms];
	if (dependencyCombinationMaximum > 0 && terms.length > dependencyCombinationMaximum) {
		result = [];
	}
	if (terms.length > 1) {
		terms.forEach(term => {
			result = union(
				result, 
				getCombinations(without(terms, term))
			);
		});
	}
	return result;
}

// builds a list of combinations of the given terms
// (with permutations)
function getCombinationsWithPermutations(terms) {
	const combinations = getCombinations(terms);
	let result = [];
	combinations.forEach(combination => {
		result = union(result, getPermutations(combination), true);
	});
	return result;
}

function getEventName() {
	return copyFromDataLayer('event');
}

// fetches the exising (valid) keys from the dataLayer entry of this event
function getPayloadKeys() {
	const keys = [];
	const dl = copyFromWindow('dataLayer');
	if (dl.length > 0) {
		const vars = dl[dl.length - 1];
		for (let key in vars) {
			if (key.indexOf('gtm.') === 0) {
				keys.push(key);
			}
		}
	}
	if (keys.indexOf(DATA_LAYER_KEY_EVENT_ID) === -1) {
		keys.push(DATA_LAYER_KEY_EVENT_ID);
	}
	return keys;
}

// fetches the payload of the current event from the dataLayer
function getPayload() {
	const payload = {};
	const keys = getPayloadKeys();
	keys.forEach(key => {
		const value = copyFromDataLayer(key);
		if (typeof value !== 'undefined') {
			if (typeof DATA_LAYER_KEY_MAP[key] === 'undefined') {
				payload[key] = value;
			} else if (DATA_LAYER_KEY_MAP[key]) {
				payload[DATA_LAYER_KEY_MAP[key]] = value;
			}
		}
	});
	return payload;
}

function getDataLayerIndex(eventId) {
	const dl = copyFromWindow('dataLayer');
	for (let i = 0; i < dl.length; i++) {
		if (dl[i] && dl[i][DATA_LAYER_KEY_EVENT_ID] === eventId) {
			return i;
		}
	}
	return -1;
}

// trigger a pseudo event with its stored payload (from a previous event)
function fireEvent(eventName, payload) {
	const data = {'event': eventName};
	if (payload) {
		for (let key in payload) {
			data[key] = payload[key];
		}
	}
	log('trigger =', data);
	const dataLayerIndex = getDataLayerIndex(payload[DATA_LAYER_KEY_ORIGINAL_EVENT_ID]);
	if (!callInWindow('dataLayerPush', data, dataLayerIndex)) {
		dataLayerPush(data);
	}
}

// build the name of a pseudo event based on its dependencies
function getPseudoEventName(eventName, dependencies) {
	let name = eventName;
	dependencies.forEach(d => {
		name += '..' + d;
	});
	return name;
}

// test if the given event name is a pseudo event name
function isPseudoEvent() {
	const dl = copyFromWindow('dataLayer');
	if (dl.length > 0) {
		const vars = dl[dl.length - 1];
		return typeof vars[DATA_LAYER_KEY_ORIGINAL_EVENT_ID] !== 'undefined';
	}
	return false;
}

// test if all events from the given dependencyList have fired
function testDependencies(dependencyList) {
	for (var i = 0; i < dependencyList.length; i++) {
		if (history.dependenciesFired.indexOf(dependencyList[i]) === -1) {
			return false;
		}
	}
	return true;
}

// update the pseudo events for one specific event
// add pseudo events for all combinations of (known) dependencies
// that don't exist yet
function updatePseudoEvents(event) {
	const dependencyCombinations = getCombinationsWithPermutations(
		history.dependenciesFired.filter(d => d !== event.name)
	);
	dependencyCombinations.forEach(dependencyList => {
		const pseudoEventName = getPseudoEventName(event.name, dependencyList);
		if (event.pseudoEvents.indexOf(pseudoEventName) === -1) {
			fireEvent(pseudoEventName, event.payload);
			event.pseudoEvents.push(pseudoEventName);
		}
	});
}

// update the pseudo events for all events
function updateAllPseudoEvents() {
	history.events.forEach(event => {
		updatePseudoEvents(event);
	});
}

// add a new event to the history
// trigger all its (currently known) pseudo events
function addObservedEvent(eventName, payload) {
	const event = {
		'name': eventName,
		'payload': payload,
		'pseudoEvents': []
	};
	history.events.push(event);
	updatePseudoEvents(event);
}

// add a dependecy event
// update pseudo events of all observed events afterwards
// then process all pseudo events that are ready
function addDependencyEvent(eventName) {
	if (history.dependenciesFired.indexOf(eventName) === -1) {
		history.dependenciesFired.push(eventName);
		updateAllPseudoEvents();
	}
}

// test if a given event name is contained in a list of names
// (wildcards are allowed)
function eventFound(eventName, eventNameList) {
	// an empty comparison list will accept all event names
	if (eventNameList.length === 0) {
		return true;
	}

	// a direct negative hit will be rejected right away
	if (eventNameList.indexOf('!' + eventName) > -1) {
		return false;
	}

	// a direct hit will be accepted
	if (eventNameList.indexOf(eventName) > -1) {
		return true;
	}

	// if wildcards exist, we need to match a regular expression
	let matched = false;
	for (let i = 0; i < eventNameList.length; i++) {
		if (eventNameList[i].indexOf('*') > -1) {
			const block = eventNameList[i][0] === '!';
			const name = block ? eventNameList[i].substring(1) : eventNameList[i];
			const regexp = '^' + name.replace('.', '\\.').replace('*', '.*') + '$';
			if (eventName.match(regexp)) {
				if (block) {
					return false;
				} else {
					matched = true;
				}
			}
		}
	}
	return matched;
}

// process an incoming real event
function processEvent(eventName, payload) {
	// if this is a dependency event, remember that it has fired now
	// then update the existing events and fire them with their new dependency
	if (dependencies.length > 0 && eventFound(eventName, dependencies)) {
		addDependencyEvent(eventName);
	}

	// if this is an observed event, queue its extended events as pending
	if (eventFound(eventName, observed)) {
		addObservedEvent(eventName, payload);
	}
}

if (!isPseudoEvent()) {
	const eventName = getEventName();
	log('eventName =', eventName);
	
	const payload = getPayload();
	log('payload =', payload);
	
	processEvent(eventName, payload);
	log('history =', history);
	
	templateStorage.setItem(HISTORY_STORAGE_KEY, JSON.stringify(history));
}

data.gtmOnSuccess();


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayer"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayerPush"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "event"
              },
              {
                "type": 1,
                "string": "gtm.*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Trigger dependent event
  code: |
    tagConfig.dependencies = ['dependency_1'];
    tagConfig.observed = ['observed_1'];

    history.dependenciesFired.push('dependency_1');
    setHistoryInput();

    dataLayerInput.event = 'observed_1';
    dataLayerInput['gtm.test'] = 'payload_1';
    runCode(tagConfig);

    assertThat(dataLayerOutput.length).isEqualTo(1);
    const triggeredEvent = dataLayerOutput[0];
    assertThat(triggeredEvent.event).isEqualTo('observed_1..dependency_1');
    assertThat(triggeredEvent['gtm.test']).isEqualTo('payload_1');

    assertApi('gtmOnSuccess').wasCalled();
- name: Do not trigger dependent event
  code: |
    tagConfig.dependencies = ['dependency_1'];
    tagConfig.observed = ['observed_1'];

    setHistoryInput();

    dataLayerInput.event = 'observed_1';
    dataLayerInput['gtm.test'] = 'payload_1';
    runCode(tagConfig);

    assertThat(dataLayerOutput.length).isEqualTo(0);
    assertApi('gtmOnSuccess').wasCalled();
setup: |-
  const templateStorage = require('templateStorage');
  const json = require('JSON');

  const tagConfig = {
    dependencies: [],
    observed: [],
    dependencyCombinationMaximum: 0
  };

  // mock('logToConsole', function() {});

  let history = {
    'dependenciesFired': [],
    'events': []
  };
  function setHistoryInput() {
    templateStorage.setItem('history', json.stringify(history));
  }
  function getHistoryOutput() {
    return templateStorage.getItem('history');
  }

  let dataLayerOutput = [];
  mock('createQueue', function(key) {
    if (key !== 'dataLayer') {
      fail('invalid queue key', key);
    }
    return function(pushed) {
      dataLayerOutput.push(pushed);
    };
  });

  let dataLayerInput = {};
  mock('copyFromDataLayer', function(key) {
    return dataLayerInput[key];
  });

  let windowDataLayer = [dataLayerInput];
  mock('copyFromWindow', function(key) {
    if (key === 'dataLayer') {
      return windowDataLayer;
    }
    fail('invalid window key', key);
  });


___NOTES___

Created on 23/05/2022, 11:28:13


