with Files.Types;

--  Test-only queries of Files.Model: state the suite inspects and the program
--  never asks for, kept out of the program.
package Files.Model.Testing is

   --  @param Model Window whose measurement to inspect.
   --  @return True when its size helper is active.
   function Folder_Scan_Is_Active (Model : Window_Model) return Boolean;
   --  @param Model Window whose measurement to inspect.
   --  @return Active measurement path, or empty when idle.
   function Folder_Scan_Target (Model : Window_Model) return String;
   --  Return the number of active inline rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Count of rename fields (zero when rename is inactive).
   function Rename_Field_Count
     (Model : Window_Model)
      return Natural;
   --  Return the rename state for the item shown at Visible_Index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible row index.
   --  @param Active Set True when that row has an active rename field.
   --  @param Value Field text (empty when inactive).
   --  @param Cursor Field caret byte offset (zero when inactive).
   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural);
   --  Return whether the current selection is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the pending create-file item is selected.
   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean;
   --  Return the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to inspect.
   --  @return Number of visible item columns used as the vertical movement stride.
   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive;
   --  Return the kind of the top undo entry.
   --
   --  @param Model Model to inspect.
   --  @return Undo_None when the undo stack is empty.
   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind;
   --  Return the top undo entry's "to" (restore-target) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of restore targets, parallel to Undo_From_Paths.
   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;
end Files.Model.Testing;
