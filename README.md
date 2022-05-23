# Google Tag Manager - Event Dependency Manager

## Description

The tag "Event Dependency Manager" is providing pseudo events to fire as soon as a specific events and all its dependent event have fired.

## Examples

In order for the following examples to work, the dependency manager needs to be setup accordingly, wich will be explained further below.

### Dependent Page View

The following example for a pseudo event will be fired as soon as `gtm.js` (Page View) and the custom event `extra_data.loaded` have both fired.

```
gtm.js..extra_data.loaded
```

### Dependent Click Event

The following example for a pseudo event will be fired once for each event `gtm.click` as soon as the custom event `extra_data.loaded` has fired.

```
gtm.click.extra_data.loaded
```

### Dependent Custom Event

The following example for a pseudo event will be fired once both `my_data.loaded` and gtm.load (Window Loaded) have fired. If `my_data.loaded` can fire multiple times, the pseudo event will also fire multiple times as soon as `gtm.load` has fired at least once.

```
my_data.loaded..gtm.load
```

## Installation

### Google Tag Manager

First import the tag template `event-dependency-manager.tpl` in your GTM container.

You only need to add one tag of this type. It needs to be triggered for every event, which can be achieved by creating a new trigger which fires on custom events with the name `.*` as regular expression.

### Extend Event Payload

Unfortunately template tags have some restrictions which make it impossible to add all payload data from an original event to a pseudo event. Especially complex objects and DOM-related data can not be copied. That is why the event data `gtm.element` which is holding a DOM element cannot be copied to a pseudo event.

Furthermore the tag template is limited to native event data, which means all data that is starting with `gtm.`.

In order to get around those restrictions, the JavaScript `extend-event-payload.js` can be included on the website directly. It will provide a global function `dataLayerPush` which will be used by the dependency system to extend the event payload and add all missing data.

## Setup

### Dependency Events

List of events that can be used as dependencies. Use wildcards `*` to match multiple events. Start with `!` to exclude events.

The system will not treat all events as possible dependencies because this would result in a flood of pseudo events. Therefore, an empty list will not result in all events being dependencies.

### Dependent Events

List of dependent events. Leave blank to enable all events. Use wildcards `*` to match multiple events. Start with `!` to exclude events.

### Dependency Combination Maximum

Limits the maximum amount of dependencies that can be used in combination at once. This will limit the amount of simultaneously triggered pseudo events if many different dependencies are in play. Leave at 0 to have no limit set.

### Examples

#### Page View depends on Custom Data loaded

Dependent Events:
```
gtm.js
```

Dependency Events:
```
my_data.loaded
```

Real Events:
```
gtm.js
my_data.loaded
```

Pseudo Events:
```
gtm.js..my_data.loaded
```

#### Page View, DOM Ready and Window Loaded all depend on Custom Data Loaded

Dependent Events:
```
gtm.*
!gtm.init*
```

Dependency Events:
```
my_data.loaded
```

Real Events:
```
gtm.init_consent
gtm.init
gtm.js
gtm.dom
gtm.load
my_data.loaded
```

Pseudo Events:
```
gtm.js..my_data.loaded
gtm.dom..my_data.loaded
gtm.load..my_data.loaded
```

#### Page View and Custom Data Loaded depend on Custom Data Loaded

Dependent Events:
```
gtm.js
*.loaded
```

Dependency Events:
```
*.loaded
```

Real Events:
```
gtm.js
my_data.loaded
my_other_data.loaded
```

Pseudo Events:
```
gtm.js..my_data.loaded
gtm.js..my_other_data.loaded
gtm.js..my_data.loaded..my_other_data.loaded
gtm.js..my_other_data.loaded..my_data.loaded
my_data.loaded..my_other_data.loaded
my_other_data.loaded..my_data_loaded
```

#### Page View and depends on multiple Sets of Custom Data Loaded

Dependent Events:
```
gtm.js
```

Dependency Events:
```
*.loaded
```

Dependency Combination Maximum: `0`

Real Events:
```
gtm.js
a.loaded
b.loaded
c.loaded
```

Pseudo Events:
```
gtm.js..a.loaded
gtm.js..b.loaded
gtm.js..c.loaded
gtm.js..a.loaded..b.loaded
gtm.js..a.loaded..c.loaded
gtm.js..b.loaded..a.loaded
gtm.js..b.loaded..c.loaded
gtm.js..c.loaded..a.loaded
gtm.js..c.loaded..b.loaded
gtm.js..a.loaded..b.loaded..c.loaded
gtm.js..a.loaded..c.loaded..b.loaded
gtm.js..b.loaded..a.loaded..c.loaded
gtm.js..b.loaded..c.loaded..a.loaded
gtm.js..c.loaded..a.loaded..b.loaded
gtm.js..c.loaded..b.loaded..a.loaded
```

#### Page View and depends on multiple Sets of Custom Data Loaded

Dependent Events:
```
gtm.js
```

Dependency Events:
```
*.loaded
```

Dependency Combination Maximum: `2`

Real Events:
```
gtm.js
a.loaded
b.loaded
c.loaded
```

Pseudo Events:
```
gtm.js..a.loaded
gtm.js..b.loaded
gtm.js..c.loaded
gtm.js..a.loaded..b.loaded
gtm.js..a.loaded..c.loaded
gtm.js..b.loaded..a.loaded
gtm.js..b.loaded..c.loaded
gtm.js..c.loaded..a.loaded
gtm.js..c.loaded..b.loaded
```

#### Page View and depends on multiple Sets of Custom Data Loaded

Dependent Events:
```
gtm.js
```

Dependency Events:
```
*.loaded
```

Dependency Combination Maximum: `1`

Real Events:
```
gtm.js
a.loaded
b.loaded
c.loaded
```

Pseudo Events:
```
gtm.js..a.loaded
gtm.js..b.loaded
gtm.js..c.loaded
```
