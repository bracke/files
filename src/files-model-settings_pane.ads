with Guikit.Settings_Panel;
--  The settings pane: its draft, and the guikit settings panel holding
--  its focus, scroll, sections and shortcut capture.
--
--  Guikit.Settings_Panel owns the focus, scroll, hit-testing and rendering;
--  the operations here forward input to it, and the caller drains the
--  emitted change with Take_Change to apply it; the localized fields and
--  the mapping of a change onto the draft are built outside the model
--  (by the settings form) and handed in. Shortcut fields capture by
--  press: arming a focused Shortcut row (by click, or Begin_Capture on a
--  keyboard activation) makes Is_Capturing true; the controller then routes
--  the next physical chord here instead of acting on it, formats it to text,
--  and commits it with Set_Captured_Shortcut (empty text unbinds) or cancels
--  with Cancel_Capture.
package Files.Model.Settings_Pane is

   --  Close the settings pane, handing back its focus. It opens only through
   --  Begin_Edit, with a draft of the settings and the panel's fields for it.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Return whether the settings pane is visible.
   --
   --  @param Model Model to inspect.
   --  @return True when the settings pane is open.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Begin editing settings values in the settings pane. The model never
   --  builds the panel's (localized) fields itself: the caller hands them in,
   --  built from the normalized draft (Files.Settings.Normalize_Draft). Draft
   --  is also what the pane takes the file to hold (Saved_Of).
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to edit, normalized.
   --  @param Fields The panel's fields for Draft.
   procedure Begin_Edit
     (Model  : in out Window_Model;
      Draft  : Files.Settings.Settings_Draft;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector);

   --  Return the current settings draft.
   --
   --  @param Model Model to inspect.
   --  @return Editable settings draft.
   function Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft;

   --  Replace the active settings draft and the panel's fields for it, so
   --  the panel never holds another draft's values (a key typed straight
   --  after a change lands on the entry the draft now shows). The caller
   --  normalizes the draft and builds the fields (Files.Settings_Form).
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to store, normalized.
   --  @param Fields The panel's fields for Draft.
   procedure Set_Draft
     (Model  : in out Window_Model;
      Draft  : Files.Settings.Settings_Draft;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector);

   --  The draft of the settings as saved: what the pane opened on, or the
   --  settings last saved (Set_Saved) -- applied, even when their write
   --  failed and was reported. A change saves only when it would make the
   --  settings hold something else.
   --
   --  @param Model Model to inspect.
   --  @return The saved settings' draft.
   function Saved_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft;

   --  Record what the file now holds, after a save.
   --
   --  @param Model Model to update.
   --  @param Saved The draft of the saved settings.
   procedure Set_Saved
     (Model : in out Window_Model;
      Saved : Files.Settings.Settings_Draft);

   --  Move keyboard focus over the panel's fields (sections are skipped).
   --
   --  @param Model Model to update.
   --  @param Delta_Rows Signed number of fields to move focus.
   procedure Move_Focus (Model : in out Window_Model; Delta_Rows : Integer);

   --  Advance/retreat the focused toggle or choice, or step a focused number.
   --
   --  @param Model Model to update.
   --  @param Forward True to advance, False to retreat.
   procedure Cycle_Choice (Model : in out Window_Model; Forward : Boolean);

   --  Replace the whole value of the focused text field.
   --
   --  @param Model Model to update.
   --  @param Text New text value.
   procedure Set_Focused_Value (Model : in out Window_Model; Text : String);

   --  Scroll the panel content by whole rows (positive scrolls down).
   --
   --  @param Model Model to update.
   --  @param Lines Rows to scroll.
   procedure Scroll (Model : in out Window_Model; Lines : Integer);

   --  Hit-test a window coordinate, focusing/editing the field under it.
   --
   --  @param Model Model to update.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return True when a field was hit.
   function Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

   --  The change emitted by the panel's most recent input (clears on read).
   --
   --  @param Model Model to update.
   --  @return The pending change.
   function Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change;

   --  The focused field's current value ("" when none).
   --
   --  @param Model Model to inspect.
   --  @return The focused field's value.
   function Focused_Value (Model : Window_Model) return String;

   --  The focused field's kind (Section when none), so keys that act only on
   --  some kinds -- Space flips a toggle but types into a text field -- can
   --  tell them apart.
   --
   --  @param Model Model to inspect.
   --  @return The focused field's kind.
   function Focused_Kind (Model : Window_Model) return Guikit.Settings_Panel.Field_Kind;

   --  The focused field's Key ("" when none).
   --
   --  @param Model Model to inspect.
   --  @return The focused field's Key.
   function Focused_Key (Model : Window_Model) return String;

   --  Show the Ordinal-th settings section (clamped to the available range),
   --  moving focus to its first field. Used to drive the tab switcher
   --  programmatically (keyboard tab navigation and tests).
   --
   --  @param Model Model to update.
   --  @param Ordinal One-based section ordinal.
   procedure Set_Active_Section (Model : in out Window_Model; Ordinal : Natural);

   --  The number of settings sections (tabs) in the current field list.
   --
   --  @param Model Model to inspect.
   --  @return Section count (0 before the panel has been laid out).
   function Section_Count (Model : Window_Model) return Natural;

   --  The one-based ordinal of the currently shown settings section.
   --
   --  @param Model Model to inspect.
   --  @return Active section ordinal.
   function Active_Section (Model : Window_Model) return Natural;

   --  Arm the focused field for capture when it is an enabled Shortcut field.
   --
   --  @param Model Model to update.
   procedure Begin_Capture (Model : in out Window_Model);

   --  Whether a Shortcut field is armed for capture.
   --
   --  @param Model Model to inspect.
   --  @return True while a chord is being captured.
   function Is_Capturing (Model : Window_Model) return Boolean;

   --  The command identifier of the armed Shortcut field ("" when none). The
   --  field Key is "shortcut.<identifier>"; this returns that whole Key.
   --
   --  @param Model Model to inspect.
   --  @return The armed field's Key, or "".
   function Capturing_Key (Model : Window_Model) return String;

   --  Commit a captured chord (empty Text unbinds) to the armed field, disarm,
   --  and emit the panel's Value_Changed.
   --
   --  @param Model Model to update.
   --  @param Text The formatted chord text, or "" to unbind.
   procedure Set_Captured_Shortcut (Model : in out Window_Model; Text : String);

   --  Configure the settings panel (Config, built by the window layer with its
   --  localized texts, and the form's Fields) and hand it to Draw, which
   --  draws it: the model holds the panel's state, the window layer renders.
   --
   --  @param Model Model whose panel to visit.
   --  @param Config The panel's configuration this frame.
   --  @param Fields The form's fields this frame.
   --  @param Draw Draws the panel.
   procedure With_Panel
     (Model  : in out Window_Model;
      Config : Guikit.Settings_Panel.Configuration;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector;
      Draw   : not null access procedure (Panel : in out Guikit.Settings_Panel.Panel));

   --  Disarm capture without changing any field.
   --
   --  @param Model Model to update.
   procedure Cancel_Capture (Model : in out Window_Model);

end Files.Model.Settings_Pane;
