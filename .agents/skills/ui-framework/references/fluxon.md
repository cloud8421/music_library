# Fluxon UI Components Usage Rules

This document provides a guide for Large Language Models (LLMs) on how to use Fluxon UI components. It covers component attributes, slots, and provides usage examples for different scenarios.

## Accordion

The Accordion component provides collapsible content sections with headers that toggle panel visibility.

### Components
- `accordion`: Main container that manages state and accessibility
- `accordion_item`: Individual collapsible sections

### Attributes

#### accordion
- `id` (string, optional): Unique identifier for the accordion container
- `class` (any, optional): Additional CSS classes for the accordion container
- `multiple` (boolean, default: false): Allow multiple items to be expanded simultaneously
- `prevent_all_closed` (boolean, default: false): Prevent all items from being closed at once
- `animation_duration` (integer, default: 300): Duration of expand/collapse animation in milliseconds
- `rest`: Additional HTML attributes

#### accordion_item
- `id` (string, optional): Unique identifier for the accordion item
- `class` (any, optional): Additional CSS classes for the accordion item container
- `expanded` (boolean, default: false): Initial expanded state of the item
- `icon` (boolean, default: true): Show/hide the chevron icon
- `rest`: Additional HTML attributes

### Slots

#### accordion
- `inner_block` (required): Contains one or more accordion_item components

#### accordion_item
- `header` (required): Always-visible clickable area that toggles the panel
  - `class` (optional): Additional CSS classes for the header button
- `panel` (required): Expandable content area
  - `class` (optional): Additional CSS classes for the panel content

### Usage Examples

#### Basic Accordion
```heex
<.accordion>
  <.accordion_item>
    <:header>What is Fluxon?</:header>
    <:panel>
      Fluxon is a powerful UI component library for Phoenix LiveView applications.
    </:panel>
  </.accordion_item>

  <.accordion_item>
    <:header>How do I get started?</:header>
    <:panel>
      Add Fluxon to your dependencies and follow the installation guide.
    </:panel>
  </.accordion_item>
</.accordion>
```

#### Multiple Sections and Rich Headers
```heex
<.accordion multiple>
  <.accordion_item>
    <:header class="flex items-center gap-3">
      <.icon name="document" class="size-5 text-zinc-400" />
      <div>
        <h3 class="font-medium">Documentation</h3>
        <p class="text-sm text-zinc-500">View the complete documentation</p>
      </div>
      <.badge class="ml-auto">New</.badge>
    </:header>
    <:panel>Detailed documentation content...</:panel>
  </.accordion_item>
</.accordion>
```

#### Custom Animation and No Icon
```heex
<.accordion animation_duration={500}>
  <.accordion_item icon={false}>
    <:header>Custom Header Without Chevron</:header>
    <:panel>No chevron icon is shown for this item</:panel>
  </.accordion_item>
</.accordion>
```

## Alert

The Alert component displays status messages, notifications, and interactive feedback with various visual styles and interactive elements.

### Attributes
- `id` (string, optional): Unique identifier for the alert element
- `class` (any, optional): Additional CSS classes for the alert element
- `title` (string, optional): Main heading text of the alert
- `subtitle` (string, optional): Secondary text displayed alongside the title
- `color` (string, default: "default"): Visual style color - "default", "primary", "danger", "success", "info", "warning"
- `hide_icon` (boolean, default: false): Hide the alert's status icon
- `hide_close` (boolean, default: false): Hide the alert's close button
- `on_close` (JS, default: %JS{}): LiveView JS commands to execute when closed

### Slots
- `inner_block` (optional): Main content displayed in the alert body
- `icon` (optional): Custom icon to replace the default status icon

### Usage Examples

#### Basic Alert with Colors
```heex
<.alert>Simple alert message</.alert>

<.alert color="info" title="Update Available">
  A new version of the application is ready to install.
</.alert>

<.alert color="success" title="Order Confirmed">
  Your order has been successfully processed.
</.alert>

<.alert color="warning" title="Session Expiring">
  Your session will expire in 5 minutes.
</.alert>

<.alert color="danger" title="Connection Lost">
  Unable to connect to the server.
</.alert>
```

#### Alert with Actions
```heex
<.alert
  color="warning"
  title="Unsaved Changes"
  on_close={JS.push("dismiss_warning")}>
  You have unsaved changes that will be lost.

  <div class="mt-4 flex space-x-2">
    <.button size="xs">Save Changes</.button>
    <.button size="xs" color="ghost">Discard</.button>
  </div>
</.alert>
```

#### Non-dismissible and Custom Icon
```heex
<.alert hide_close>
  This alert cannot be dismissed
</.alert>

<.alert>
  <:icon>
    <.icon name="hero-bell" class="size-5" />
  </:icon>
  Custom notification icon
</.alert>
```

## Autocomplete

The Autocomplete component provides a text input that filters a list of options as the user types, with keyboard navigation and accessibility features. It supports both client-side and server-side search capabilities.

### Attributes
- `id` (any, optional): Unique identifier for the autocomplete component
- `name` (any): Form name for the autocomplete (required when not using `field`)
- `field` (Phoenix.HTML.FormField, optional): Form field to bind to
- `class` (any, optional): Additional CSS classes for the field wrapper element
- `label` (string, optional): Primary label for the autocomplete
- `sublabel` (string, optional): Additional context displayed beside the main label
- `help_text` (string, optional): Help text displayed below the autocomplete
- `description` (string, optional): Description displayed below the label
- `placeholder` (string, optional): Text to display when input is empty
- `autofocus` (boolean, default: false): Whether input should have autofocus
- `disabled` (boolean, default: false): Disable the autocomplete component
- `size` (string, default: "md"): Size variant - "xs", "sm", "md", "lg", "xl"
- `search_threshold` (integer, default: 0): Minimum characters before showing suggestions
- `no_results_text` (string, default: "No results found for \"%{query}\"."): Text for no results
- `on_search` (string, optional): LiveView event name for server-side search
- `debounce` (integer, default: 200): Debounce time in milliseconds for server-side searches
- `search_mode` (string, default: "contains"): Search mode - "contains", "starts-with", "exact"
- `open_on_focus` (boolean, default: false): Open listbox when input is focused
- `value` (any, optional): Current selected value
- `errors` (list, default: []): List of error messages
- `options` (list, required): List of options in various formats
- `clearable` (boolean, default: false): Show clear button to remove selection
- `rest`: Additional HTML attributes

### Slots
- `inner_prefix` (optional): Content inside input field before text
- `outer_prefix` (optional): Content outside and before input field
- `inner_suffix` (optional): Content inside input field after text
- `outer_suffix` (optional): Content outside and after input field
- `option` (optional): Custom option rendering slot
- `empty_state` (optional): Custom empty state rendering
- `header` (optional): Custom header content for listbox
- `footer` (optional): Custom footer content for listbox

### Usage Examples

#### Basic and Form Integration
```heex
<.autocomplete
  name="country"
  options={[{"United States", "us"}, {"Canada", "ca"}]}
  placeholder="Search countries..."
/>

<.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
  <.autocomplete
    field={f[:user_id]}
    label="Assigned To"
    options={@users}
  />
</.form>
```

#### Different Option Formats
```heex
<!-- List of strings -->
<.autocomplete
  name="fruits"
  options={["Apple", "Banana", "Cherry"]}
  placeholder="Search fruits..."
/>

<!-- Grouped options -->
<.autocomplete
  name="products"
  options={[
    {"Fruits", [{"Apple", "apple"}, {"Banana", "banana"}]},
    {"Vegetables", [{"Carrot", "carrot"}, {"Broccoli", "broccoli"}]}
  ]}
  placeholder="Search products..."
/>
```

#### Size Variants and Labels
```heex
<.autocomplete name="sm" size="sm" placeholder="Small" options={@options} />
<.autocomplete name="lg" size="lg" placeholder="Large" options={@options} />

<.autocomplete
  name="language"
  label="Programming Language"
  sublabel="Required"
  description="Choose the web framework for your project"
  help_text="Choose from our supported platforms"
  placeholder="Select your favorite..."
  options={["Elixir", "Phoenix", "LiveView"]}
/>
```

#### Affixes and Search Features
```heex
<!-- With icon prefix -->
<.autocomplete name="user_search" options={@users} placeholder="Search users...">
  <:inner_prefix>
    <.icon name="hero-magnifying-glass" class="size-4" />
  </:inner_prefix>
</.autocomplete>

<!-- Server-side search -->
<.autocomplete
  name="movie"
  options={@movies}
  on_search="search_movies"
  search_threshold={2}
  clearable
  placeholder="Type to search movies..."
/>
```

#### Custom Option Rendering
```heex
<.autocomplete
  name="users"
  placeholder="Search team members..."
  options={[{"John Doe", "john"}, {"Jane Smith", "jane"}]}
>
  <:option :let={{label, value}}>
    <div class="flex items-center gap-3">
      <div class="size-8 rounded-full bg-gradient-to-r from-blue-500 to-purple-500 flex items-center justify-center text-white text-sm font-bold">
        {String.first(label)}
      </div>
      <div>
        <div class="font-medium text-sm">{label}</div>
        <div class="text-xs text-zinc-500">@{value}</div>
      </div>
    </div>
  </:option>
</.autocomplete>
```

## Badge

The Badge component provides versatile visual markers for status indicators, categories, and notification counts with semantic colors, size variants, and visual styles.

### Attributes
- `class` (any, optional): Additional CSS classes for the badge element
- `color` (string, default: "primary"): Semantic color - "primary", "info", "success", "warning", "danger"
- `size` (string, default: "md"): Size variant - "xs", "sm", "md", "lg", "xl"
- `variant` (string, default: "surface"): Visual style - "solid", "soft", "surface", "outline", "dashed", "ghost"
- `rest`: Additional HTML attributes

### Slots
- `inner_block` (required): Content displayed within the badge (text, icons, or both)

### Usage Examples

#### Colors and Variants
```heex
<.badge>Default Badge</.badge>
<.badge color="success">Active</.badge>
<.badge color="danger" size="lg">Error</.badge>
<.badge variant="ghost" color="info">Draft</.badge>

<.badge variant="solid" color="success">High Emphasis</.badge>
<.badge variant="soft" color="info">Medium Emphasis</.badge>
<.badge variant="outline" color="primary">Outline</.badge>
```

#### Size Variants
```heex
<.badge size="xs">Extra Small</.badge>
<.badge size="sm">Small</.badge>
<.badge size="lg">Large</.badge>
```

#### With Icons and Interactive
```heex
<.badge color="success">
  <.icon name="hero-check-circle" class="icon" /> Verified
</.badge>

<!-- Toggle selection state -->
<.badge
  color={if @selected, do: "primary", else: "info"}
  variant={if @selected, do: "solid", else: "dashed"}
  phx-click="toggle_selection"
  class="cursor-pointer"
>
  <.icon :if={@selected} name="hero-check" class="icon" />
  Category
</.badge>
```

## Button

The Button component provides consistent, accessible, and visually appealing interactive elements for actions and navigation. It automatically renders either a `<button>` or `<a>` tag based on provided attributes.

### Components
- `button`: Interactive button/link element
- `button_group`: Container to group multiple buttons visually

### Attributes

#### button
- `color` (string, default: "primary"): Semantic color - "primary", "danger", "warning", "success", "info"
- `size` (string, default: "md"): Size variant - "xs", "sm", "md", "lg", "xl", "icon-xs", "icon-sm", "icon-md", "icon", "icon-lg", "icon-xl"
- `variant` (string, default: "outline"): Visual style - "solid", "soft", "surface", "outline", "dashed", "ghost"
- `disabled` (boolean, default: false): Whether the button is disabled
- `class` (any, optional): Additional CSS classes for the button
- `rest`: Additional HTML attributes (supports both button and anchor attributes)

#### button_group
- `class` (any, optional): Additional CSS classes for the group container
- `rest`: Additional HTML attributes for the group container

### Slots

#### button
- `inner_block` (required): Content displayed within the button (text, icons, etc.)

#### button_group
- `inner_block` (required): Buttons to be grouped together

### Usage Examples

#### Basic Buttons and Variants
```heex
<.button>Outline Button (Default)</.button>
<.button variant="solid" color="primary">Solid Button</.button>
<.button variant="soft" color="primary">Soft Button</.button>
<.button variant="ghost">Ghost Button</.button>
```

#### Colors and Sizes
```heex
<.button color="primary" variant="solid">Primary</.button>
<.button color="danger" variant="soft">Danger</.button>
<.button color="success" variant="surface">Success</.button>

<.button size="xs">Extra Small</.button>
<.button size="lg">Large</.button>
<.button size="xl">Extra Large</.button>
```

#### Icon Buttons
```heex
<.button size="icon-sm">
  <.icon name="hero-pencil" class="icon" />
</.button>

<.button size="icon" variant="solid" color="primary">
  <.icon name="hero-magnifying-glass" class="icon" />
</.button>

<.button size="lg" variant="solid" color="success">
  <.icon name="hero-check-circle" class="icon" /> Order Confirmed
</.button>
```

#### Automatic Link Rendering
```heex
<!-- Renders as <a> tag -->
<.button navigate={~p"/dashboard"} variant="solid" color="primary">
  Go to Dashboard
</.button>

<.button href="https://example.com" target="_blank" variant="soft">
  External Link
</.button>
```

#### Interactive Examples
```heex
<!-- Danger Action -->
<.button variant="solid" color="danger" phx-click="delete_item" phx-value-id={@item.id} phx-confirm="Are you sure?">
  <.icon name="hero-trash" class="icon" />
  Delete Item
</.button>

<!-- Icon-Only with ARIA label -->
<.button size="icon" variant="ghost" phx-click="show-details" phx-value-id={@user.id} aria-label="View user details">
  <.icon name="hero-eye" class="icon" />
</.button>
```

#### Button Group
```heex
<.button_group>
  <.button>Year</.button>
  <.button>Month</.button>
  <.button>Week</.button>
</.button_group>
```

## Checkbox

The Checkbox component provides versatile checkbox inputs for capturing single and multiple selections. It offers both standard and card variants with comprehensive form integration and accessibility features.

### Components
- `checkbox`: Single checkbox input for boolean or single-value selections
- `checkbox_group`: Container for multiple related checkbox selections

### Attributes

#### checkbox
- `id` (any, optional): Unique identifier for the checkbox
- `name` (any): Form name for the checkbox (required when not using `field`)
- `checked` (boolean, optional): Whether the checkbox is checked
- `value` (any, optional): Value associated with the checkbox
- `errors` (list, default: []): List of error messages
- `label` (string, optional): Primary label for the checkbox
- `sublabel` (string, optional): Additional context beside the main label
- `description` (string, optional): Detailed description below the label
- `class` (any, optional): Additional CSS classes for the checkbox
- `field` (Phoenix.HTML.FormField, optional): Form field to bind to
- `variant` (string, optional): Visual variant - `nil` (default), `"card"`
- `control` (string, optional): Position of checkbox in card variant - "left", "right"
- `rest`: Additional HTML attributes

#### checkbox_group
- `id` (any, optional): Unique identifier for the checkbox group
- `name` (string): Form name for the checkbox group (required when not using `field`)
- `value` (any, optional): Current value(s) of the checkbox group (list of selected values)
- `label` (string, optional): Primary label for the checkbox group
- `sublabel` (string, optional): Additional context beside the main label
- `description` (string, optional): Detailed description of the checkbox group
- `errors` (list, default: []): List of error messages
- `class` (any, optional): Additional CSS classes for the group container
- `field` (Phoenix.HTML.FormField, optional): Form field to bind to
- `disabled` (boolean, default: false): Disable all checkboxes in the group
- `variant` (string, optional): Visual variant - `nil` (default), `"card"`
- `control` (string, optional): Position of checkbox in card variant - "left", "right"
- `rest`: Additional HTML attributes

### Slots

#### checkbox
- `inner_block` (optional): Custom content for the checkbox (replaces standard label structure in card variants)

#### checkbox_group
- `checkbox` (required): Individual checkboxes within the group

### Usage Examples

#### Basic Checkbox and Form Integration
```heex
<.checkbox
  name="terms"
  label="I agree to the terms and conditions"
  value="accepted"
/>

<.form :let={f} for={@form} phx-change="validate" phx-submit="save">
  <.checkbox
    field={f[:marketing_emails]}
    label="Marketing emails"
    sublabel="Receive updates about new features and promotions"
  />
</.form>
```

#### Card Variant
```heex
<.checkbox
  control="left"
  field={f[:notifications]}
  variant="card"
  label="Push Notifications"
  sublabel="Stay informed"
  description="Get real-time updates for messages and activity"
  value="enabled"
/>
```

#### Checkbox Group
```heex
<.checkbox_group
  name="preferences"
  label="Notification Preferences"
  description="Choose when you want to receive notifications"
>
  <:checkbox value="email" label="Email notifications" />
  <:checkbox value="push" label="Push notifications" />
  <:checkbox value="sms" label="SMS notifications" />
</.checkbox_group>

<.form :let={f} for={@form} phx-change="validate" phx-submit="save">
  <.checkbox_group
    field={f[:notification_preferences]}
    label="Notification Preferences"
    description="Choose how you want to be notified"
  >
    <:checkbox value="email" label="Email" sublabel="Get notified via email" />
    <:checkbox value="push" label="Push" sublabel="Receive push notifications" />
  </.checkbox_group>
</.form>
```

#### Custom Card Content
```heex
<.checkbox variant="card" name="feature" value="advanced">
  <div class="flex items-center gap-3">
    <div class="p-2 rounded bg-blue-100">
      <.icon name="hero-star" class="size-5 text-blue-600" />
    </div>
    <div>
      <h3 class="font-medium">Advanced Features</h3>
      <p class="text-sm text-gray-600">Access premium functionality</p>
    </div>
  </div>
</.checkbox>
```

## DatePicker

The DatePicker component provides calendar-based date selection with support for single dates, multiple dates, date ranges, and time selection. It includes configurable sizing and affix slots for UI customization.

### Components
- `date_picker`: Single date selection with optional multiple date support
- `date_time_picker`: Date and time selection
- `date_range_picker`: Date range selection with start and end dates

### Attributes

#### date_picker
- `id` (any, optional): Unique identifier for the date picker
- `name` (any): Form name for the date picker (required when not using `field`)
- `field` (Phoenix.HTML.FormField, optional): Form field to bind to
- `value` (any, optional): Current selected value
- `multiple` (boolean, default: false): Allow selecting multiple dates
- `label` (string, optional): Primary label for the date picker
- `sublabel` (string, optional): Additional context beside the main label
- `description` (string, optional): Detailed description below the label
- `help_text` (string, optional): Help text displayed below the component
- `placeholder` (string, optional): Text to display when no date is selected
- `size` (string, default: "md"): Size variant - "xs", "sm", "md", "lg", "xl"
- `min` (Date/string, optional): Minimum selectable date
- `max` (Date/string, optional): Maximum selectable date
- `disabled` (boolean, default: false): Disable the date picker
- `errors` (list, default: []): List of error messages
- `display_format` (string, default: "%b %-d, %Y"): Format for displaying selected dates
- `week_start` (integer, default: 0): Day of week to start calendar (0=Sunday, 1=Monday, etc.)
- `rest`: Additional HTML attributes

#### date_time_picker
- All attributes from `date_picker` plus:
- `time_format` (string, default: "24"): Time format - "12" (12-hour) or "24" (24-hour)

#### date_range_picker
- `id` (any, optional): Unique identifier for the date range picker
- `start_name` (string): Form name for the start date (required when not using fields)
- `end_name` (string): Form name for the end date (required when not using fields)
- `start_field` (Phoenix.HTML.FormField, optional): Start date form field to bind to
- `end_field` (Phoenix.HTML.FormField, optional): End date form field to bind to
- `start_value` (any, optional): Current start date value
- `end_value` (any, optional): Current end date value
- Plus other shared attributes

### Slots (All Components)
- `inner_prefix` (optional): Content inside the field border, before the date display
- `outer_prefix` (optional): Content outside and before the field
- `inner_suffix` (optional): Content inside the field border, after the date display
- `outer_suffix` (optional): Content outside and after the field

### Usage Examples

#### Basic Date Pickers
```heex
<.date_picker
  name="appointment"
  label="Appointment Date"
  placeholder="Select a date"
/>

<.date_time_picker
  name="meeting"
  label="Meeting Time"
  time_format="12"
  placeholder="Select date and time"
/>

<.date_range_picker
  start_name="check_in"
  end_name="check_out"
  label="Stay Period"
  placeholder="Select date range"
/>
```

#### Size Variants and Labels
```heex
<.date_picker name="sm" size="sm" label="Small Date" placeholder="Small" />
<.date_picker name="lg" size="lg" label="Large Date" placeholder="Large" />

<.date_picker
  name="event_date"
  label="Event Date"
  sublabel="Required"
  description="Choose when your event will take place"
  help_text="Events can be scheduled up to 6 months in advance"
  placeholder="Select event date"
/>
```

#### Date Constraints and Multiple Selection
```heex
<!-- Future dates only -->
<.date_picker
  name="appointment"
  label="Appointment Date"
  min={Date.utc_today()}
  max={Date.add(Date.utc_today(), 60)}
  placeholder="Select your appointment date"
/>

<.date_picker
  name="available_dates"
  label="Available Dates"
  multiple
  placeholder="Select multiple dates"
/>
```

#### Form Integration with Affixes
```heex
<.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
  <.date_picker
    field={f[:appointment_date]}
    label="Appointment Date"
    placeholder="Choose date"
  />

  <.date_range_picker
    start_field={f[:start_date]}
    end_field={f[:end_date]}
    label="Date Range"
    placeholder="Choose date range"
  />
</.form>

<!-- With calendar icon -->
<.date_picker name="appointment" label="Appointment Date" placeholder="Select date">
  <:inner_prefix>
    <.icon name="hero-calendar-days" class="icon" />
  </:inner_prefix>
</.date_picker>
```

## Dropdown

The Dropdown component provides a comprehensive system for creating accessible, interactive menus and selection interfaces with proper keyboard navigation and focus management.

### Components
- `dropdown`: Main dropdown container
- `dropdown_link`: Link menu item for navigation
- `dropdown_button`: Button menu item for actions
- `dropdown_header`: Section header for organizing menu items
- `dropdown_separator`: Visual separator between menu sections
- `dropdown_custom`: Custom content container for rich menu items

### Attributes

#### dropdown
- `id` (string, optional): Unique identifier for the dropdown component
- `label` (string, default: "Menu"): Text label for the default toggle button
- `class` (any, optional): Additional CSS classes for the dropdown container
- `placement` (string, default: "bottom-start"): Menu position relative to toggle
- `open_on_hover` (boolean, default: false): Enable hover-based opening
- `hover_open_delay` (integer, default: 100): Delay before opening on hover (ms)
- `hover_close_delay` (integer, default: 300): Delay before closing when leaving hover (ms)
- `rest`: Additional HTML attributes

#### Other dropdown components
- `class` (any, optional): Additional CSS classes for the element
- `rest`: Additional HTML attributes

### Slots

#### dropdown
- `toggle` (optional): Custom toggle element to replace the default button
- `inner_block` (required): Menu items and content

#### All other dropdown components
- `inner_block` (required): Content for the menu item/element

### Usage Examples

#### Basic Dropdown
```heex
<.dropdown>
  <.dropdown_link navigate={~p"/profile"}>Profile</.dropdown_link>
  <.dropdown_link navigate={~p"/settings"}>Settings</.dropdown_link>
  <.dropdown_separator />
  <.dropdown_link href={~p"/logout"} method="delete">Sign Out</.dropdown_link>
</.dropdown>
```

#### Custom Toggle and Rich Content
```heex
<.dropdown>
  <:toggle>
    <button class="flex items-center gap-x-2 bg-zinc-200/50 rounded-lg p-2">
      <img src={~p"/images/human-avatar-01.png"} alt="User" class="size-6 rounded-lg" />
      <div class="text-sm text-gray-800 font-semibold">John Doe</div>
      <.icon name="hero-chevron-down" class="size-4" />
    </button>
  </:toggle>
  <.dropdown_button>Profile</.dropdown_button>
  <.dropdown_button>Settings</.dropdown_button>
</.dropdown>

<.dropdown class="w-64">
  <.dropdown_custom class="flex items-center p-2">
    <img src="https://i.pravatar.cc/150?u=1" alt="Avatar" class="size-9 rounded-full" />
    <div class="flex flex-col ml-3">
      <span class="text-sm font-medium">Emma Johnson</span>
      <span class="text-xs text-zinc-500">emma@acme.com</span>
    </div>
  </.dropdown_custom>

  <.dropdown_separator />

  <.dropdown_header>Account</.dropdown_header>
  <.dropdown_link navigate={~p"/profile"}>Profile</.dropdown_link>
  <.dropdown_link navigate={~p"/billing"}>Billing</.dropdown_link>
</.dropdown>
```

#### Hover Interaction and Button Actions
```heex
<.dropdown open_on_hover hover_open_delay={200} hover_close_delay={300}>
  <.dropdown_link navigate={~p"/profile"}>Profile</.dropdown_link>
  <.dropdown_link navigate={~p"/settings"}>Settings</.dropdown_link>
</.dropdown>

<.dropdown>
  <.dropdown_button phx-click="export_data">Export Data</.dropdown_button>
  <.dropdown_button phx-click="import_data">Import Data</.dropdown_button>
  <.dropdown_separator />
  <.dropdown_button phx-click="delete_all" phx-confirm="Are you sure?">
    Delete All
  </.dropdown_button>
</.dropdown>
```

## Input

The Input component provides versatile text input fields with support for various types, sizes, form integration, and customizable prefix/suffix content both inside and outside the input field.

### Components
- `input`: Main text input component
- `input_group`: Container for visually grouping multiple related inputs

### Attributes

#### input
- `id` (any, optional): HTML id attribute for the input element
- `name` (any): Form name for the input (required when not using `field`)
- `field` (Phoenix.HTML.FormField, optional): Form field to bind to
- `value` (any, optional): Current input value
- `type` (string, default: "text"): HTML input type
- `label` (string, optional): Primary label for the input
- `sublabel` (string, optional): Additional context beside the main label
- `description` (string, optional): Detailed description below the label
- `help_text` (string, optional): Help text displayed below the input
- `placeholder` (string, optional): Placeholder text
- `size` (string, default: "md"): Size variant - "xs", "sm", "md", "lg", "xl"
- `disabled` (boolean, default: false): Disable the input
- `readonly` (boolean, optional): Make input readonly
- `errors` (list, default: []): List of error messages
- `class` (any, optional): Additional CSS classes
- `rest`: Additional HTML attributes

#### input_group
- `class` (any, optional): Additional CSS classes for the group container
- `label` (string, optional): Primary label for the input group
- `sublabel` (string, optional): Additional context beside the main label
- `description` (string, optional): Detailed description of the input group
- `help_text` (string, optional): Help text displayed below the group
- `rest`: Additional HTML attributes

### Slots

#### input
- `inner_prefix` (optional): Content inside the input border, before the text
- `outer_prefix` (optional): Content outside and before the input field
- `inner_suffix` (optional): Content inside the input border, after the text
- `outer_suffix` (optional): Content outside and after the input field

#### input_group
- `inner_block` (required): Input elements and controls to be grouped

### Usage Examples

#### Basic Input and Size Variants
```heex
<.input name="username" label="Username" placeholder="Enter username..." />
<.input name="password" type="password" label="Password" />
<.input name="email" type="email" label="Email" />

<.input name="input_sm" size="sm" placeholder="Small" />
<.input name="input_lg" size="lg" placeholder="Large" />
<.input name="input_xl" size="xl" placeholder="Extra Large" />
```

#### Complete Labeling and Form Integration
```heex
<.input
  name="full_example"
  label="Email Address"
  sublabel="(required)"
  description="We'll send a confirmation link here."
  help_text="We never share your email."
  placeholder="you@example.com"
/>

<.form :let={f} for={@form}>
  <.input field={f[:email]} type="email" label="Email" />
  <.input field={f[:password]} type="password" label="Password" />
</.form>
```

#### Input States and Types
```heex
<!-- Disabled and readonly -->
<.input name="disabled_input" value="Cannot change" disabled />
<.input name="readonly_input" value="Readonly value" readonly />

<!-- Different types -->
<.input type="date" name="date_input" label="Appointment Date" />
<.input type="number" name="count" label="Quantity" min="1" max="10" />
<.input type="search" name="site_search" placeholder="Search site..." />
```

#### Inner Affixes
```heex
<!-- Email with icon -->
<.input name="email_icon" placeholder="user@example.com">
  <:inner_prefix>
    <.icon name="hero-at-symbol" class="icon" />
  </:inner_prefix>
</.input>

<!-- Password with visibility toggle -->
<.input name="password_toggle" type="password" value="secretpassword">
  <:inner_suffix>
    <.button variant="ghost" size="icon-sm" title="Show password">
      <.icon name="hero-eye" class="icon" />
    </button>
  </:inner_suffix>
</.input>

<!-- URL with static prefix -->
<.input name="url_prefix" placeholder="yourdomain.com">
  <:inner_prefix class="pointer-events-none text-zinc-500">https://www.</:inner_prefix>
</.input>
```

#### Outer Affixes
```heex
<!-- With send button -->
<.input name="invite_user" placeholder="user@example.com">
  <:inner_prefix>
    <.icon name="hero-at-symbol" class="icon" />
  </:inner_prefix>
  <:outer_suffix>
    <.button variant="solid" color="primary">
      <.icon name="hero-paper-airplane" class="icon" /> Invite
    </button>
  </:outer_suffix>
</.input>

<!-- Currency input with prefix and suffix -->
<.input name="website_url" placeholder="mysite">
  <:outer_prefix class="px-2 text-zinc-500">https://</:outer_prefix>
  <:outer_suffix class="px-2 text-zinc-500">.example.com</:outer_suffix>
</.input>
```

#### Input Groups
```heex
<!-- Name inputs -->
<.input_group label="Full Name">
  <.input name="first_name" placeholder="First Name" />
  <.input name="last_name" placeholder="Last Name" />
</.input_group>

<!-- Price range with separator -->
<.input_group label="Price Range">
  <.input name="min_price" placeholder="Min price">
    <:inner_prefix>$</:inner_prefix>
  </.input>
  <div class="shrink-0 bg-gray-100 border-y border-gray-200 shadow-sm self-stretch flex items-center justify-center px-2 text-gray-500">
    to
  </div>
  <.input name="max_price" placeholder="Max price">
    <:inner_prefix>$</:inner_prefix>
  </.input>
</.input_group>
```

## Loading

The Loading component provides versatile animated loading indicators for displaying loading states with multiple animation styles and customization options.

### Attributes
- `class` (any, optional): Additional CSS classes for customizing size and color (default: size-5, text-zinc-600)
- `duration` (integer, default: 600): Duration of one complete animation cycle in milliseconds
- `variant` (string, default: "ring"): Animation style - "ring", "ring-bg", "dots-bounce", "dots-fade", "dots-scale"
- `rest`: Additional HTML attributes

### Usage Examples

#### Animation Variants
```heex
<.loading />
<.loading variant="ring-bg" />
<.loading variant="dots-bounce" />
<.loading variant="dots-fade" />
<.loading variant="dots-scale" />
```

#### Size and Color Variations
```heex
<.loading class="size-4" />
<.loading class="size-8" />
<.loading class="size-12" />

<.loading class="text-blue-500" />
<.loading class="text-green-500" />
<.loading class="text-red-500" />
```

#### Button Loading States
```heex
<.button disabled>
  <.loading class="size-4" /> Loading...
</.button>

<.button variant="solid" color="primary" disabled>
  <.loading class="size-4 text-white" /> Processing
</.button>
```

#### Page and Section Loading
```heex
<!-- Full page loading -->
<div class="flex items-center justify-center min-h-[400px]">
  <.loading class="size-8" />
</div>

<!-- Loading overlay -->
<div class="relative">
  <div class="absolute inset-0 flex items-center justify-center bg-white/80 rounded">
    <.loading class="size-6" />
  </div>
  <!-- Content being loaded -->
</div>

<!-- Inline loading -->
<p>Processing your request <.loading class="size-4 inline" variant="dots-bounce" /></p>
```

## Modal

The Modal component provides a powerful and accessible modal overlay for displaying focused content with LiveView integration, supporting both client-side and server-side control.

### Attributes
- `id` (string, required): Unique identifier for the modal component
- `open` (boolean, default: false): Whether the modal is initially open
- `on_close` (JS, optional): JavaScript commands to execute when the modal closes
- `on_open` (JS, optional): JavaScript commands to execute when the modal opens
- `class` (any, optional): Additional CSS classes for the modal content container
- `container_class` (any, optional): CSS classes for the outer modal container
- `close_on_esc` (boolean, default: true): Whether pressing ESC closes the modal
- `close_on_outside_click` (boolean, default: true): Whether clicking outside closes the modal
- `prevent_closing` (boolean, default: false): Prevent all client-side closing behaviors
- `hide_close_button` (boolean, default: false): Hide the default close button
- `animation` (string, default: "transition duration-300 ease-out"): Animation classes
- `animation_enter` (string, default: "opacity-100 scale-100"): Enter animation classes
- `animation_leave` (string, default: "opacity-0 scale-95"): Leave animation classes
- `backdrop_class` (string, optional): Custom classes for the modal backdrop
- `placement` (string, default: "center"): Modal positioning on screen
- `rest`: Additional HTML attributes

### Slots
- `inner_block` (required): Content displayed within the modal

### Usage Examples

#### Basic Modal
```heex
<.button phx-click={Fluxon.open_dialog("basic-modal")}>Open Modal</.button>

<.modal id="basic-modal">
  <div class="p-6">
    <h2 class="text-lg font-semibold mb-4">Modal Title</h2>
    <p>This is the modal content.</p>

    <div class="flex gap-2 mt-6">
      <.button phx-click={Fluxon.close_dialog("basic-modal")}>Close</.button>
    </div>
  </div>
</.modal>
```

#### Server-Side Control
```heex
<.button phx-click="show_modal">Open Server Modal</.button>

<.modal id="server-modal" open={@show_modal} on_close={JS.push("hide_modal")}>
  <div class="p-6">
    <h2 class="text-lg font-semibold">Server Controlled Modal</h2>
    <p>This modal is controlled by server state.</p>
    <.button phx-click="hide_modal" class="mt-4">Close</.button>
  </div>
</.modal>

<!-- Server-only control -->
<.modal id="secure-modal" open={@show_secure_modal} prevent_closing>
  <div class="p-6">
    <h2 class="text-lg font-semibold text-red-600">Critical Operation</h2>
    <p>This modal can only be closed through server commands.</p>
    <.button phx-click="hide_secure_modal" color="danger" class="mt-4">
      Complete Action
    </.button>
  </div>
</.modal>
```

#### Custom Styling and Form Modal
```heex
<!-- Large modal -->
<.modal
  id="large-modal"
  class="w-full max-w-4xl max-h-[80vh] overflow-auto"
  container_class="p-4"
>
  <div class="p-8">
    <h2 class="text-2xl font-bold mb-6">Large Modal</h2>
    <p>This modal has custom sizing and scrolling behavior.</p>
  </div>
</.modal>

<!-- Form modal -->
<.modal id="form-modal" on_close={JS.push("reset_form")}>
  <div class="p-6">
    <h2 class="text-lg font-semibold mb-4">Create User</h2>

    <.form :let={f} for={@changeset} phx-change="validate" phx-submit="create_user">
      <.input field={f[:name]} label="Full Name" />
      <.input field={f[:email]} type="email" label="Email" />

      <div class="flex gap-2 mt-6">
        <.button type="submit" disabled={!@changeset.valid?}>
          Create User
        </.button>
        <.button
          type="button"
          variant="outline"
          phx-click={Fluxon.close_dialog("form-modal")}
        >
          Cancel
        </.button>
      </div>
    </.form>
  </div>
</.modal>
```

#### Confirmation Modal
```heex
<.modal id="confirm-delete" class="w-96">
  <div class="p-6 text-center">
    <div class="w-12 h-12 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
      <.icon name="hero-exclamation-triangle" class="size-6 text-red-600" />
    </div>

    <h2 class="text-lg font-semibold mb-2">Delete Item</h2>
    <p class="text-gray-600 mb-6">
      Are you sure you want to delete this item? This action cannot be undone.
    </p>

    <div class="flex gap-2 justify-center">
      <.button
        color="danger"
        phx-click="confirm_delete"
        phx-value-id={@delete_item_id}
      >
        Delete
      </.button>
      <.button
        variant="outline"
        phx-click={Fluxon.close_dialog("confirm-delete")}
      >
        Cancel
      </.button>
    </div>
  </div>
</.modal>
```

## Navlist

The Navlist component provides a comprehensive navigation system for building structured, accessible navigation menus with support for sections, headings, and interactive links.

### Components
- `navlist`: Main navigation container that provides structure and spacing
- `navheading`: Optional section headers for organizing navigation groups
- `navlink`: Interactive navigation items with LiveView integration

### Attributes

#### navlist
- `heading` (string, optional): Primary heading for the navigation section
- `class` (any, optional): Additional CSS classes for the navigation container
- `rest`: Additional HTML attributes for the nav container

#### navheading
- `class` (any, optional): Additional CSS classes for the heading element
- `rest`: Additional HTML attributes

#### navlink
- `class` (any, optional): Additional CSS classes for the navigation link
- `active` (boolean, default: false): Whether this navigation item is currently active
- `rest`: Additional HTML attributes (supports navigation attributes like `navigate`, `patch`, `href`, etc.)

### Slots

#### navlist
- `inner_block` (required): Navigation items and headings

#### navheading
- `inner_block` (required): Heading content

#### navlink
- `inner_block` (required): Link content (text, icons, badges, etc.)

### Usage Examples

#### Basic Navigation
```heex
<.navlist heading="Main Navigation">
  <.navlink navigate={~p"/dashboard"} active>
    <.icon name="hero-home" class="size-5" /> Dashboard
  </.navlink>
  <.navlink navigate={~p"/projects"}>
    <.icon name="hero-folder" class="size-5" /> Projects
  </.navlink>
  <.navlink navigate={~p"/settings"}>
    <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
  </.navlink>
</.navlist>
```

#### Multiple Sections
```heex
<.navlist heading="Main">
  <.navlink navigate={~p"/dashboard"} active>
    <.icon name="hero-home" class="size-5" /> Dashboard
  </.navlink>
  <.navlink navigate={~p"/projects"}>
    <.icon name="hero-folder" class="size-5" /> Projects
  </.navlink>
</.navlist>

<.navlist heading="Settings">
  <.navlink navigate={~p"/profile"}>
    <.icon name="hero-user" class="size-5" /> Profile
  </.navlink>
  <.navlink navigate={~p"/preferences"}>
    <.icon name="hero-cog-6-tooth" class="size-5" /> Preferences
  </.navlink>
</.navlist>
```

#### Navigation with Badges
```heex
<.navlist heading="Inbox">
  <.navlink navigate={~p"/inbox/unread"}>
    <.icon name="hero-envelope" class="size-5" />
    Unread
    <.badge variant="solid" color="danger" class="ml-auto">23</.badge>
  </.navlink>

  <.navlink navigate={~p"/inbox/starred"}>
    <.icon name="hero-star" class="size-5" />
    Starred
    <.badge variant="soft" color="warning" class="ml-auto">5</.badge>
  </.navlink>
</.navlist>
```

#### External Links and Actions
```heex
<.navlist heading="Resources">
  <.navlink href="https://docs.example.com" target="_blank">
    <.icon name="hero-document-text" class="size-5" />
    Documentation
    <.icon name="hero-arrow-top-right-on-square" class="size-4 ml-auto text-gray-400" />
  </.navlink>
</.navlist>

<.navlist heading="Actions">
  <.navlink phx-click="export_data">
    <.icon name="hero-arrow-down-tray" class="size-5" />
    Export Data
  </.navlink>

  <.navlink phx-click="refresh_data">
    <.icon name="hero-arrow-path" class="size-5" />
    Refresh
  </.navlink>
</.navlist>
```

## Popover

A powerful and accessible popover component that displays floating content anchored to a trigger element.

### Attributes
- `id` (string, default: auto-generated): Optional unique identifier for the popover
- `target` (string, default: nil): CSS selector of an external element to use as positioning reference
- `class` (any, default: nil): Additional CSS classes for the popover content container
- `open_on_hover` (boolean, default: false): Opens popover on hover for tooltip-like behavior
- `open_on_focus` (boolean, default: false): Opens popover when trigger receives focus
- `placement` (string, default: "top"): Popover position - "top", "top-start", "top-end", "right", "right-start", "right-end", "left", "left-start", "left-end", "bottom", "bottom-start", "bottom-end"

### Slots
- `inner_block`: The trigger element that will open the popover (optional when using target)
- `content` (required): The content to display in the popover

### Usage Examples

#### Basic Tooltip
```heex
<.popover open_on_hover>
  <.icon name="hero-information-circle" class="text-zinc-400" />

  <:content>
    <p class="text-sm">The invoice will be generated at the end of the month.</p>
  </:content>
</.popover>
```

#### Interactive Menu and Form Help
```heex
<.popover placement="bottom-end" class="w-64">
  <.button variant="ghost">
    <.icon name="hero-cog-6-tooth" /> Settings
  </.button>

  <:content>
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">Dark Mode</span>
        <.switch name="dark_mode" checked />
      </div>
      <.button size="sm" class="w-full">
        Reset Preferences
      </.button>
    </div>
  </:content>
</.popover>

<.input name="api-key" label="API Key" value="sk_test_..." class="font-mono">
  <:inner_suffix>
    <.popover open_on_hover placement="right">
      <.icon name="hero-question-mark-circle" class="text-zinc-400" />

      <:content>
        <div class="max-w-xs space-y-2">
          <p class="text-sm font-medium">About API Keys</p>
          <p class="text-sm text-zinc-600">
            Your API key is used to authenticate requests. Keep it secure.
          </p>
        </div>
      </:content>
    </.popover>
  </:inner_suffix>
</.input>
```

#### Search Suggestions
```heex
<.popover open_on_focus placement="bottom-start" class="w-80">
  <.input type="search" placeholder="Search users..." phx-debounce="300" />

  <:content>
    <div :if={@loading} class="p-4 flex justify-center">
      <.loading />
    </div>
    <div :for={user <- @users} class="p-2 hover:bg-zinc-50 cursor-pointer">
      <div class="font-medium">{user.name}</div>
      <div class="text-sm text-zinc-600">{user.email}</div>
    </div>
  </:content>
</.popover>
```

## Radio

A versatile radio component for building single-selection interfaces with rich styling options.

### Attributes
- `id` (any, default: nil): The unique identifier for the radio group
- `name` (string, required when not using field): The form name for the radio group
- `value` (any): The current selected value of the radio group
- `label` (string, default: nil): The primary label for the radio group
- `sublabel` (string, default: nil): Additional context displayed beside the main label
- `description` (string, default: nil): Detailed description below the label
- `errors` (list, default: []): List of error messages
- `class` (any, default: nil): Additional CSS classes for the radio group container
- `field` (Phoenix.HTML.FormField): The form field to bind to
- `disabled` (boolean, default: false): Disables all radio buttons in the group
- `variant` (string, default: nil): Visual variant - nil (default) or "card"
- `control` (string): Controls radio position in card variants - "left" or "right"
- `rest` (global): Additional attributes

### Slots
- `radio` (required): Defines individual radio buttons with attributes: `value`, `label`, `sublabel`, `description`, `disabled`, `class`, `checked`

### Usage Examples

#### Basic Radio Group
```heex
<.radio_group name="system" value="debian" label="Operating System">
  <:radio value="ubuntu" label="Ubuntu" />
  <:radio value="debian" label="Debian" />
  <:radio value="fedora" label="Fedora" />
</.radio_group>
```

#### With Context and Form Integration
```heex
<.radio_group
  name="system"
  label="Operating System"
  sublabel="Choose your preferred OS"
  description="Select the operating system that best suits your needs"
>
  <:radio
    value="ubuntu"
    label="Ubuntu"
    sublabel="Popular and user-friendly"
    description="Ubuntu is a Debian-based Linux operating system"
  />
  <:radio
    value="debian"
    label="Debian"
    sublabel="Stable and reliable"
    description="Debian is composed of free and open-source software"
  />
</.radio_group>

<.form :let={f} for={@form} phx-change="validate" phx-submit="save">
  <.radio_group
    field={f[:subscription]}
    label="Subscription Plan"
    description="Choose your preferred subscription plan"
  >
    <:radio value="basic" label="Basic Plan" sublabel="$10/month" />
    <:radio value="pro" label="Pro Plan" sublabel="$20/month" />
    <:radio value="enterprise" label="Enterprise Plan" sublabel="$50/month" />
  </.radio_group>
</.form>
```

#### Card Variant
```heex
<.radio_group
  name="plan"
  label="Choose a plan"
  description="Choose the plan that best suits your needs."
  variant="card"
  control="left"
  class="gap-0"
>
  <:radio value="basic" label="Basic" sublabel="Perfect for small projects" class="rounded-none -my-px rounded-t-lg" />
  <:radio value="pro" label="Professional" checked sublabel="Most popular for growing teams" class="rounded-none -my-px" />
  <:radio value="business" label="Business" sublabel="Advanced features for larger teams" class="rounded-none -my-px rounded-b-lg" />
</.radio_group>

<.radio_group name="category" label="Category" variant="card" class="grid grid-cols-3">
  <:radio value="web-design" class="flex-1 group has-checked:border-blue-500 has-checked:bg-blue-50">
    <div class="flex flex-col justify-center items-center w-full gap-2">
      <.icon name="hero-computer-desktop" class="size-6 text-zinc-500 group-has-checked:text-blue-500" />
      <span class="font-medium text-sm group-has-checked:text-zinc-800">Web Design</span>
    </div>
  </:radio>
  <:radio value="ui-ux" class="flex-1 group has-checked:border-blue-500 has-checked:bg-blue-50">
    <div class="flex flex-col justify-center items-center w-full gap-2">
      <.icon name="hero-pencil" class="size-6 text-zinc-500 group-has-checked:text-blue-500" />
      <span class="font-medium text-sm group-has-checked:text-zinc-800">UI/UX Design</span>
    </div>
  </:radio>
</.radio_group>
```

## Select

A select component that implements a modern, accessible selection interface with support for single and multiple selections.

### Attributes
- `id` (any, default: nil): The unique identifier for the select component
- `name` (any, required when not using field): The form name for the select
- `field` (Phoenix.HTML.FormField): The form field to bind to
- `native` (boolean, default: false): Renders a native HTML select element instead of custom select
- `class` (any, default: nil): Additional CSS classes for the select component
- `label` (string, default: nil): The primary label for the select
- `sublabel` (string, default: nil): Additional context beside the main label
- `help_text` (string, default: nil): Help text displayed below the select
- `description` (string, default: nil): Description below the label but above select
- `placeholder` (string, default: nil): Text displayed when no option is selected
- `searchable` (boolean, default: false): Adds search input to filter options (custom select only)
- `disabled` (boolean, default: false): Disables the select component
- `size` (string, default: "md"): Controls select size - "xs", "sm", "md", "lg", "xl"
- `search_input_placeholder` (string, default: "Search..."): Placeholder for search input
- `search_no_results_text` (string, default: "No results found for %{query}."): No results text
- `search_threshold` (integer, default: 0): Minimum characters before filtering
- `debounce` (integer, default: 300): Debounce time for server searches
- `on_search` (string, default: nil): LiveView event name for server searches
- `multiple` (boolean, default: false): Allows selecting multiple options (not with native)
- `value` (any): Current selected value(s)
- `errors` (list, default: []): List of error messages
- `options` (list, required): List of options for the select
- `max` (integer, default: nil): Maximum selections when multiple
- `clearable` (boolean, default: false): Shows clear button
- `rest` (global): Additional attributes

### Slots
- `option`: Optional slot for custom option rendering
- `toggle`: Optional slot for custom toggle rendering
- `header`: Optional slot for custom header content
- `footer`: Optional slot for custom footer content
- `inner_prefix`: Content inside select field before value display
- `outer_prefix`: Content outside and before select field
- `inner_suffix`: Content inside select field after value display
- `outer_suffix`: Content outside and after select field

### Usage Examples

#### Basic and Full-featured Select
```heex
<.select
  name="country"
  options={[{"United States", "US"}, {"Canada", "CA"}]}
/>

<.select
  name="payment_method"
  label="Payment Method"
  sublabel="Select payment type"
  description="Choose your preferred payment method"
  help_text="We securely process all payment information"
  placeholder="Select payment method"
  options={[
    {"Credit Card", "credit_card"},
    {"PayPal", "paypal"},
    {"Bank Transfer", "bank_transfer"}
  ]}
/>
```

#### Native, Searchable and Multiple
```heex
<.select
  name="country"
  native
  options={[{"United States", "US"}, {"Canada", "CA"}]}
/>

<.select
  name="country"
  searchable
  search_input_placeholder="Search for a country"
  search_no_results_text="No countries found for %{query}"
  options={@countries}
/>

<.select
  name="countries"
  multiple
  max={3}
  clearable
  options={[{"United States", "US"},{"Canada", "CA"},{"Mexico", "MX"}]}
/>
```

#### Form Integration and Affixes
```heex
<.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
  <.select
    field={f[:country]}
    label="Country"
    options={@countries}
  />
</.form>

<.select name="category" options={@categories} placeholder="Select category">
  <:inner_prefix>
    <.icon name="hero-folder" class="icon" />
  </:inner_prefix>
  <:outer_suffix>
    <.button size="md">Apply</.button>
  </:outer_suffix>
</.select>
```

#### Custom Option Rendering
```heex
<.select
  name="role"
  placeholder="Select role"
  options={[{"Admin", "admin"}, {"Editor", "editor"}, {"Viewer", "viewer"}]}
>
  <:option :let={{label, value}}>
    <div class="flex items-center justify-between rounded-lg py-2 px-3">
      <div>
        <div class="font-medium text-sm">{label}</div>
        <div class="text-zinc-500 text-xs">
          {case value do
            "admin" -> "Full access to all features"
            "editor" -> "Can create and modify content"
            "viewer" -> "Read-only access to content"
          end}
        </div>
      </div>
      <.icon :if={value == "admin"} name="hero-shield-check" class="size-4 text-blue-500" />
    </div>
  </:option>
</.select>
```

## Separator

A versatile separator component for creating visual boundaries between content sections.

### Attributes
- `text` (string, default: nil): Optional text to display in the center of the separator
- `vertical` (boolean, default: false): Renders a vertical separator instead of horizontal
- `class` (any, default: nil): Additional CSS classes

### Usage Examples

#### Basic Separators
```heex
<div class="py-2">Content above</div>
<.separator />
<div class="py-2">Content below</div>

<div class="flex h-8 items-center gap-4">
  <span>Left</span>
  <.separator vertical />
  <span>Right</span>
</div>

<.separator text="or" />
<.separator text="Section" class="my-6" />
```

#### Form and Navigation Usage
```heex
<form class="space-y-4">
  <.input name="email" type="email" placeholder="Email" />
  <.input name="password" type="password" placeholder="Password" />
  <.button type="submit" class="w-full">Sign In</.button>

  <.separator text="or" />

  <.button type="button" variant="outline" class="w-full">
    Sign in with Google
  </.button>
</form>

<div class="flex items-center gap-4">
  <span>Profile</span>
  <.separator vertical />
  <span>Settings</span>
  <.separator vertical />
  <span>Logout</span>
</div>
```

## Sheet

A powerful and accessible sheet component that provides a sliding panel interface for displaying content from screen edges.

### Attributes
- `id` (string, required): The unique identifier for the sheet component
- `open` (boolean, default: false): Whether the sheet is initially open
- `on_close` (JS, default: %JS{}): JavaScript commands to execute when sheet closes
- `on_open` (JS, default: %JS{}): JavaScript commands to execute when sheet opens
- `class` (any, default: ""): Additional CSS classes for sheet content container
- `close_on_esc` (boolean, default: true): Whether to close sheet when Escape is pressed
- `close_on_outside_click` (boolean, default: true): Whether to close when clicking outside
- `prevent_closing` (boolean, default: false): Prevents sheet from being closed through standard interactions
- `hide_close_button` (boolean, default: false): Whether to hide the close button
- `animation` (string, default: "transition duration-200 ease-in-out"): Base animation classes
- `animation_enter` (string): Classes applied when sheet enters (auto-set based on placement)
- `animation_leave` (string): Classes applied when sheet leaves (auto-set based on placement)
- `backdrop_class` (string, default: ""): Additional CSS classes for backdrop overlay
- `placement` (string, default: "left"): Edge the sheet slides from - "left", "right", "top", "bottom"

### Slots
- `inner_block` (required): The content of the sheet

### Usage Examples

#### Basic Client-Side Control
```heex
<.button phx-click={Fluxon.open_dialog("filters-sheet")}>Filters</.button>

<.sheet id="filters-sheet">
  <h3 class="text-lg font-semibold mb-4">Filters</h3>

  <div class="space-y-4">
    <!-- Filter content -->
  </div>

  <.button phx-click={Fluxon.close_dialog("filters-sheet")}>Apply</.button>
</.sheet>
```

#### Server-Side Control
```heex
<.button phx-click="show-sheet">Open Filters</.button>

<.sheet id="filters-sheet" open={@show_filters}>
  <h3 class="text-lg font-semibold">Server-controlled Sheet</h3>
</.sheet>

<!-- With state sync -->
<.sheet
  id="filters-sheet"
  open={@show_filters}
  on_close={JS.push("hide_filters")}
>
  <h3 class="text-lg font-semibold">Filters with State Sync</h3>
</.sheet>
```

#### Different Placements
```heex
<!-- Left drawer for navigation -->
<.sheet id="nav-sheet" placement="left" class="w-80">
  <nav class="space-y-2">
    <.navlink href="/dashboard">Dashboard</.navlink>
    <.navlink href="/projects">Projects</.navlink>
  </nav>
</.sheet>

<!-- Right sheet for details -->
<.sheet id="details-sheet" placement="right" class="w-96">
  <h3 class="text-lg font-semibold">Details</h3>
  <p>Detailed information goes here.</p>
</.sheet>

<!-- Bottom action sheet -->
<.sheet id="actions-sheet" placement="bottom" class="h-96">
  <div class="space-y-3">
    <.button class="w-full">Share</.button>
    <.button class="w-full">Copy Link</.button>
    <.button class="w-full">Delete</.button>
  </div>
</.sheet>
```

#### Form in Sheet
```heex
<.sheet id="new-user-sheet" placement="right" class="w-96">
  <.form for={@form} phx-submit="save_user">
    <div class="space-y-4">
      <header class="mb-4">
        <h2 class="text-lg font-semibold">New User</h2>
        <p class="text-sm text-zinc-600">Create a new user account.</p>
      </header>

      <.input field={@form[:name]} label="Name" />
      <.input field={@form[:email]} type="email" label="Email" />

      <div class="flex justify-end gap-3 mt-6">
        <.button phx-click={Fluxon.close_dialog("new-user-sheet")}>
          Cancel
        </.button>
        <.button type="submit" phx-disable-with="Creating...">
          Create User
        </.button>
      </div>
    </div>
  </.form>
</.sheet>
```

## Switch

A toggle switch component for binary choices and settings with immediate effect.

### Attributes
- `id` (any, default: nil): The unique identifier for the switch
- `name` (string, required when not using field): The form name for the switch
- `class` (any, default: nil): Additional CSS classes for the switch wrapper
- `checked` (boolean): Whether the switch is in the on position
- `disabled` (boolean, default: false): Disables the switch
- `value` (any): The value associated with the switch
- `label` (string, default: nil): The primary label for the switch
- `sublabel` (string, default: nil): Additional context beside the main label
- `description` (string, default: nil): Detailed description below the label
- `size` (string, default: "md"): Controls switch size - "sm", "md", "lg"
- `color` (string, default: "primary"): Color theme when on - "primary", "danger", "success", "warning", "info"
- `field` (Phoenix.HTML.FormField): The form field to bind to
- `rest` (global): Additional attributes

### Usage Examples

#### Basic Switch and Size Variants
```heex
<.switch
  name="notifications"
  label="Enable Notifications"
  checked={@settings.notifications}
  phx-click="toggle_setting"
  phx-value-setting="notifications"
/>

<.switch name="small_switch" label="Small Switch" size="sm" checked={@settings.compact_mode} />
<.switch name="large_switch" label="Large Switch" size="lg" checked={@settings.important_setting} />
```

#### Labels and Context
```heex
<.switch name="simple" label="Enable Feature" checked={@feature_enabled} />

<.switch
  name="with_sublabel"
  label="Auto Save"
  sublabel="Recommended"
  checked={@settings.auto_save}
/>

<.switch
  name="comprehensive"
  label="Advanced Analytics"
  sublabel="Beta"
  description="Share detailed usage patterns to help improve the product experience"
  checked={@settings.analytics_enabled}
/>
```

#### Color Variants and Form Integration
```heex
<.switch name="primary" label="Default Setting" color="primary" checked={@settings.default} />
<.switch name="success" label="Enable Backup" color="success" checked={@settings.backup_enabled} />
<.switch name="danger" label="Public Profile" color="danger" checked={@settings.public_profile} />

<.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
  <.switch
    field={f[:notifications_enabled]}
    label="Push Notifications"
    sublabel="Real-time updates"
    description="Receive notifications about important account activity"
  />

  <.switch
    field={f[:email_marketing]}
    label="Email Marketing"
    sublabel="Optional"
    description="Receive promotional emails about new features"
  />
</.form>
```

#### Disabled States
```heex
<.switch
  name="disabled_off"
  label="Unavailable Feature"
  description="This feature is currently unavailable"
  disabled
  checked={false}
/>

<.switch
  name="disabled_on"
  label="Premium Feature"
  sublabel="Upgrade required"
  description="This feature requires a premium subscription"
  disabled
  checked={true}
/>
```

## Table

A comprehensive table system for displaying structured data with rich customization options.

### Components
- `table`: The main container providing structure and responsive behavior
- `table_head`: Header section with column definitions
- `table_body`: Content section containing rows of data
- `table_row`: Individual data rows with cell content

### Attributes
- All components have `class` (optional) and `rest` attributes for customization

### Slots

#### table
- `inner_block` (required): Usually contains table_head and table_body components

#### table_head
- `col` (required): Defines table columns rendered as th elements

#### table_body
- `inner_block` (required): Usually contains table_row components

#### table_row
- `cell` (required): Defines table cells with custom content and styling

### Usage Examples

#### Basic Table
```heex
<.table>
  <.table_head>
    <:col>Name</:col>
    <:col>Status</:col>
    <:col>Email</:col>
  </.table_head>

  <.table_body>
    <.table_row>
      <:cell>Alice Smith</:cell>
      <:cell>New</:cell>
      <:cell>alice@example.com</:cell>
    </.table_row>
    <.table_row>
      <:cell>Bob Johnson</:cell>
      <:cell>In Progress</:cell>
      <:cell>bob@example.com</:cell>
    </.table_row>
  </.table_body>
</.table>
```

#### Rich Content Table
```heex
<.table>
  <.table_head>
    <:col>Lead</:col>
    <:col>Stage</:col>
    <:col>Contact</:col>
    <:col></:col>
  </.table_head>
  <.table_body>
    <.table_row>
      <:cell class="w-full flex items-center gap-2">
        <img src="https://i.pravatar.cc/150?u=1" class="size-9 rounded-full" />
        <div class="flex flex-col gap-0.5">
          <span class="font-semibold">Sarah Johnson</span>
          <span class="text-zinc-400 text-sm/3">Product Manager</span>
        </div>
      </:cell>
      <:cell>
        <.badge color="green">Active</.badge>
      </:cell>
      <:cell>sarah.j@example.com</:cell>
      <:cell>
        <.icon name="hero-ellipsis-horizontal" class="size-5" />
      </:cell>
    </.table_row>
  </.table_body>
</.table>
```

#### Sortable Columns and Clickable Rows
```heex
<.table>
  <.table_head>
    <:col phx-click="sort" phx-value-column="name">
      <div class="flex items-center gap-1">
        Lead <.icon name="hero-chevron-up-down" class="size-4 text-zinc-500" />
      </div>
    </:col>
    <:col phx-click="sort" phx-value-column="stage">
      <div class="flex items-center gap-1">
        Stage <.icon name="hero-chevron-up-down" class="size-4 text-zinc-500" />
      </div>
    </:col>
  </.table_head>
  <.table_body>
    <.table_row>
      <:cell>John Smith</:cell>
      <:cell>New Lead</:cell>
    </.table_row>
  </.table_body>
</.table>

<.table>
  <.table_head>
    <:col>Customer</:col>
    <:col>Status</:col>
    <:col>Last Order</:col>
  </.table_head>

  <.table_body>
    <.table_row
      :for={customer <- @customers}
      class="cursor-pointer hover:bg-zinc-50"
      phx-click="show_customer"
      phx-value-id={customer.id}
    >
      <:cell>
        <div class="flex items-center gap-2">
          <img src={customer.avatar} class="size-8 rounded-full" />
          <span class="font-medium">{customer.name}</span>
        </div>
      </:cell>
      <:cell><.badge color="green">Active</.badge></:cell>
      <:cell>{customer.last_order_date}</:cell>
    </.table_row>
  </.table_body>
</.table>
```

#### Data Table with Actions
```heex
<.table>
  <.table_head>
    <:col>User</:col>
    <:col>Role</:col>
    <:col>Status</:col>
    <:col>Actions</:col>
  </.table_head>

  <.table_body>
    <.table_row :for={user <- @users}>
      <:cell>
        <div class="flex items-center gap-3">
          <img src={user.avatar} class="size-10 rounded-full" />
          <div>
            <div class="font-medium">{user.name}</div>
            <div class="text-sm text-zinc-500">{user.email}</div>
          </div>
        </div>
      </:cell>
      <:cell>
        <span class="inline-flex items-center rounded-full bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700">
          {user.role}
        </span>
      </:cell>
      <:cell>
        <.badge color={if user.active, do: "green", else: "red"}>
          {if user.active, do: "Active", else: "Inactive"}
        </.badge>
      </:cell>
      <:cell>
        <div class="flex items-center gap-2">
          <.button size="sm" variant="ghost" phx-click="edit_user" phx-value-id={user.id}>
            Edit
          </.button>
          <.button size="sm" variant="ghost" color="danger" phx-click="delete_user" phx-value-id={user.id}>
            Delete
          </.button>
        </div>
      </:cell>
    </.table_row>
  </.table_body>
</.table>
```

#### Empty State Table
```heex
<.table>
  <.table_head>
    <:col>Name</:col>
    <:col>Email</:col>
    <:col>Status</:col>
  </.table_head>

  <.table_body>
    <.table_row :if={Enum.empty?(@users)}>
      <:cell colspan="3" class="text-center py-12 text-zinc-500">
        <div class="flex flex-col items-center gap-3">
          <.icon name="hero-users" class="size-12 text-zinc-300" />
          <div>
            <p class="text-sm font-medium">No users found</p>
            <p class="text-xs">Get started by creating your first user.</p>
          </div>
          <.button size="sm" phx-click="new_user">Add User</.button>
        </div>
      </:cell>
    </.table_row>

    <.table_row :for={user <- @users}>
      <:cell>{user.name}</:cell>
      <:cell>{user.email}</:cell>
      <:cell>{user.status}</:cell>
    </.table_row>
  </.table_body>
</.table>
```

## Tabs

A tabs system for creating accessible, interactive tabbed interfaces with keyboard navigation support.

### Components
- `tabs`: The main container providing structure and JavaScript functionality
- `tabs_list`: Navigation container holding the interactive tab buttons
- `tabs_panel`: Content panels associated with each tab, displayed one at a time

### Attributes

#### tabs
- `id` (string): A unique identifier for the tabs container
- `class` (any, default: nil): Additional CSS classes for the tabs container
- `rest` (global): Additional HTML attributes

#### tabs_list
- `class` (any, default: nil): Additional CSS classes for the tablist container
- `active_tab` (string): The name of the tab that should be initially active
- `variant` (string, default: "default"): The visual style variant - "default", "segmented", "ghost"
- `size` (string, default: "md"): The size of the tabs container - "xs", "sm", "md"

#### tabs_panel
- `name` (string, required): The unique identifier for this panel
- `class` (any, default: nil): Additional CSS classes for the panel element
- `active` (boolean, default: false): Controls the visibility of the panel
- `rest` (global): Additional HTML attributes

### Slots

#### tabs
- `inner_block` (required): Typically contains one tabs_list and one or more tabs_panel components

#### tabs_list
- `tab` (required): Defines an individual interactive tab button with required name attribute
- `inner_block` (required): Main content area containing the tab slots

#### tabs_panel
- `inner_block` (required): The content displayed when corresponding tab is active

### Usage Examples

#### Basic Static Tabs
```heex
<.tabs id="my-tabs">
  <.tabs_list active_tab="settings">
    <:tab name="profile">Profile</:tab>
    <:tab name="settings">Settings</:tab>
    <:tab name="notifications">Notifications</:tab>
  </.tabs_list>

  <.tabs_panel name="profile">
    Profile content here...
  </.tabs_panel>

  <.tabs_panel name="settings" active>
    Settings content here...
  </.tabs_panel>

  <.tabs_panel name="notifications">
    Notifications content here...
  </.tabs_panel>
</.tabs>
```

#### Visual Variants and Sizes
```heex
<!-- Default underlined style -->
<.tabs_list variant="default">
  <:tab name="tab1">Default Tab</:tab>
</.tabs_list>

<!-- Segmented button-like style -->
<.tabs_list variant="segmented">
  <:tab name="tab1">Segmented Tab</:tab>
</.tabs_list>

<!-- Ghost style with subtle backgrounds -->
<.tabs_list variant="ghost">
  <:tab name="tab1">Ghost Tab</:tab>
</.tabs_list>

<!-- Size variants -->
<.tabs_list size="xs">
  <:tab name="tab1">Extra Small Tab</:tab>
</.tabs_list>

<.tabs_list size="sm">
  <:tab name="tab1">Small Tab</:tab>
</.tabs_list>
```

#### Rich Tab Content
```heex
<.tabs_list>
  <:tab name="messages">
    <.icon name="hero-envelope" class="icon" />
    Messages
    <.badge class="ml-2">3</.badge>
  </:tab>

  <:tab name="settings">
    <.icon name="hero-cog-6-tooth" class="icon" />
    Settings
  </:tab>
</.tabs_list>
```

#### LiveView Integration
```heex
<.tabs id="lv-sync-tabs">
  <.tabs_list active_tab={@active_tab}>
    <:tab name="profile" phx-click={JS.push("set_active_tab", value: %{tab: "profile"})}>
      Profile
    </:tab>
    <:tab name="settings" phx-click={JS.push("set_active_tab", value: %{tab: "settings"})}>
      Settings
    </:tab>
  </.tabs_list>

  <.tabs_panel name="profile" active={@active_tab == "profile"}>
    Profile content...
  </.tabs_panel>
  <.tabs_panel name="settings" active={@active_tab == "settings"}>
    Settings content...
  </.tabs_panel>
</.tabs>
```

#### Complex Form Tabs
```heex
<.tabs id="user-form-tabs">
  <.tabs_list active_tab={@active_tab} variant="segmented">
    <:tab name="basic" phx-click={JS.push("set_tab", value: %{tab: "basic"})}>
      <.icon name="hero-user" class="icon" />
      Basic Info
    </:tab>
    <:tab name="contact" phx-click={JS.push("set_tab", value: %{tab: "contact"})}>
      <.icon name="hero-envelope" class="icon" />
      Contact
    </:tab>
  </.tabs_list>

  <.tabs_panel name="basic" active={@active_tab == "basic"} class="space-y-4">
    <.input field={@form[:name]} label="Full Name" />
    <.input field={@form[:username]} label="Username" />
  </.tabs_panel>

  <.tabs_panel name="contact" active={@active_tab == "contact"} class="space-y-4">
    <.input field={@form[:email]} type="email" label="Email" />
    <.input field={@form[:phone]} label="Phone Number" />
  </.tabs_panel>
</.tabs>
```

## Textarea

A versatile textarea component for capturing multi-line text input with form integration and size variants.

### Attributes
- `id` (string, default: nil): The unique identifier for the textarea
- `field` (Phoenix.HTML.FormField): The form field to bind to
- `class` (any, default: nil): Additional CSS classes for the textarea
- `help_text` (string, default: nil): Optional help text displayed below the textarea
- `label` (string, default: nil): The primary label for the textarea
- `sublabel` (string, default: nil): Additional context beside the main label
- `description` (string, default: nil): Detailed description below the label
- `value` (string): The current value of the textarea
- `errors` (list, default: []): List of error messages
- `name` (string, required when not using field): The form name for the textarea
- `rows` (integer, default: 3): The number of visible text lines
- `disabled` (boolean, default: false): Disables the textarea
- `size` (string, default: "md"): Controls textarea size - "sm", "md", "lg", "xl"
- `rest` (global): Additional HTML attributes

### Usage Examples

#### Basic Textarea and Size Variants
```heex
<.textarea
  name="description"
  label="Description"
  placeholder="Enter description..."
/>

<.textarea name="description" label="Small" size="sm" placeholder="A compact textarea" />
<.textarea name="description" label="Large" size="lg" placeholder="Larger textarea" />
<.textarea name="description" label="Extra Large" size="xl" placeholder="Maximum emphasis" />
```

#### With Labels and Form Integration
```heex
<.textarea
  name="bio"
  label="Biography"
  help_text="Tell us about yourself"
  rows={5}
/>

<.form :let={f} for={@form} phx-change="validate" phx-submit="save">
  <.textarea
    field={f[:description]}
    label="Description"
    help_text="Provide a detailed description of your project"
  />
</.form>

<.form :let={f} for={@form} phx-change="validate">
  <.textarea
    field={f[:description]}
    label="Project Description"
    sublabel="Optional"
    description="Provide details about your project's goals and scope"
    help_text="Be specific and concise"
    rows={6}
  />
</.form>
```

#### Custom Styling and States
```heex
<.textarea
  name="notes"
  label="Meeting Notes"
  size="lg"
  class="font-mono"
  rows={10}
/>

<.textarea
  name="readonly_field"
  label="Read Only Field"
  value="This content cannot be edited"
  disabled
/>

<.textarea
  name="content"
  label="Article Content"
  rows={15}
  maxlength={5000}
  placeholder="Write your article content here..."
  spellcheck="true"
/>
```

#### Rich Form Example
```heex
<.form :let={f} for={@form} phx-change="validate" phx-submit="save">
  <div class="space-y-6">
    <.textarea
      field={f[:summary]}
      label="Summary"
      sublabel="Required"
      rows={3}
      maxlength={500}
      help_text="Brief overview of the content"
    />

    <.textarea
      field={f[:content]}
      label="Full Content"
      description="The main body of your article or post"
      rows={12}
      help_text="Use markdown formatting if needed"
    />

    <.textarea
      field={f[:notes]}
      label="Internal Notes"
      sublabel="Optional"
      size="sm"
      rows={2}
      help_text="Private notes for internal use"
    />
  </div>

  <.button type="submit">Save Article</.button>
</.form>
```

## Tooltip

A lightweight and accessible tooltip component for displaying informative content on hover or focus.

### Attributes
- `id` (string, optional): Unique identifier for the tooltip
- `value` (string, optional): Text content for simple tooltips
- `class` (any, optional): Additional CSS classes for the tooltip container
- `arrow` (boolean, default: true): Whether to show the pointing arrow indicator
- `placement` (string, default: "top"): Tooltip position - "bottom", "left", "top", "right"
- `delay` (integer, default: 0): Delay in milliseconds before showing tooltip

### Slots
- `inner_block` (required): The trigger element that shows tooltip on hover/focus
- `content` (optional): Rich content slot for complex tooltip content

### Usage Examples

#### Basic and Rich Content
```heex
<.tooltip value="Opens in a new window">
  <.button>Open</.button>
</.tooltip>

<.tooltip>
  <.button>View details</.button>

  <:content>
    <div class="space-y-2">
      <img src="/images/preview.png" class="rounded-lg w-full" />
      <p class="text-sm">Preview of the document layout and structure.</p>
    </div>
  </:content>
</.tooltip>
```

#### Different Placements and Icon Tooltips
```heex
<div class="flex gap-4">
  <.tooltip value="Top placement" placement="top">
    <.button>Top</.button>
  </.tooltip>

  <.tooltip value="Right placement" placement="right">
    <.button>Right</.button>
  </.tooltip>
</div>

<div class="flex gap-2">
  <.tooltip value="Share">
    <.button variant="ghost"><.icon name="hero-share" /></.button>
  </.tooltip>

  <.tooltip value="Add to favorites">
    <.button variant="ghost"><.icon name="hero-star" /></.button>
  </.tooltip>
</div>
```

#### Form Field Help and Custom Styling
```heex
<div class="flex items-center gap-2">
  <.input type="text" name="api_key" value="">
    <:inner_suffix>
      <.tooltip value="Your API key can be found in the developer settings">
        <.icon name="hero-question-mark-circle" class="text-zinc-400" />
      </.tooltip>
    </:inner_suffix>
  </.input>
</div>

<.tooltip
  value="Draft saved"
  class="bg-green-600 text-white"
  arrow={false}
>
  <.badge>Draft</.badge>
</.tooltip>

<.tooltip value="Archived items are hidden from the main view" delay={300}>
  <.icon name="hero-archive" class="text-zinc-400" />
</.tooltip>
```

#### User Profile Preview
```heex
<.tooltip class="max-w-xs">
  <.link navigate={"/users/#{@user.id}"}>
    {@user.name}
  </.link>

  <:content>
    <div class="space-y-1">
      <p class="font-medium">{@user.name}</p>
      <p class="text-sm text-zinc-300">{@user.title}</p>
      <p class="text-sm text-zinc-300">{@user.department}</p>
    </div>
  </:content>
</.tooltip>
```
