--  Inline rename: one editable field per renamed item, its carets and
--  edits, and the targets a commit renames.
package Files.Model.Rename is

   --  Return whether rename can start for the current selection.
   --
   --  @param Model Model to inspect.
   --  @return True when at least one non-temporary item is selected.
   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean;

   --  Toggle synchronized multi-item rename mode.
   --
   --  When starting, one inline rename field is created per selected loaded
   --  item, each with its caret placed before the file extension.
   --
   --  @param Model Model to update.
   procedure Toggle_Rename
     (Model : in out Window_Model);

   --  Return whether rename mode is active.
   --
   --  @param Model Model to inspect.
   --  @return True when rename mode is active.
   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to inspect.
   --  @return First field's rename text, or an empty string.
   function Rename_Text
     (Model : Window_Model)
      return String;

   --  Set the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to update.
   --  @param Text New rename text for the first field.
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Insert Text at every rename field's caret, advancing each caret.
   --
   --  @param Model Model to update.
   --  @param Text UTF-8 text to insert.
   --  @return True when any field changed.
   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean;

   --  Delete, at every rename field's caret, the character or word before
   --  it (Backward) or after it.
   --
   --  @param Model Model to update.
   --  @param Backward Delete before the caret; otherwise at it.
   --  @param By_Word A word rather than one character.
   --  @return True when any field changed (the revision moves only then).
   function Rename_Delete
     (Model    : in out Window_Model;
      Backward : Boolean;
      By_Word  : Boolean := False)
      return Boolean;

   --  Move every rename field's caret one character or word in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @param By_Word To the next word boundary rather than the next character.
   --  @return True when any caret moved (the revision moves only then).
   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction;
      By_Word   : Boolean := False)
      return Boolean;

   --  Move every rename field's caret to the start of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret to the end of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean;

   --  Set the caret of the rename field shown at Visible_Index only.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible row index of the clicked field.
   --  @param Position Byte offset of the new caret (clamped to a boundary).
   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural);

   --  Visit each active rename field, so a caller rendering every row can
   --  index them once instead of searching the fields per row (a rename of
   --  a whole large folder made that quadratic). Nothing is visited when no
   --  rename is active.
   --
   --  @param Model Model to inspect.
   --  @param Visit Called once per field with the three below.
   --  @param Item_Index The field's item index; zero for the pending create row.
   --  @param Value Its text.
   --  @param Cursor Its caret byte offset.
   procedure For_Each_Rename_Field
     (Model : Window_Model;
      Visit : not null access procedure (Item_Index : Natural; Value : UString; Cursor : Natural));

   type Rename_Target is record
      Item_Index    : Natural := 0;
      Old_Full_Path : UString;
      Old_Name      : UString;
      New_Name      : UString;
   end record;

   package Rename_Target_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Target);

   --  Return the commit targets for the active real-item rename fields.
   --
   --  @param Model Model to inspect.
   --  @return One target per real rename field (temporary fields excluded).
   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector;

   --  Resume single-item rename mode for the currently selected item.
   --
   --  @param Model Model to update.
   --  @param Text Rename text to restore.
   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String);

end Files.Model.Rename;
