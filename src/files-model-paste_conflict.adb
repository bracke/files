separate (Files.Model)
package body Paste_Conflict is
   use Ada.Strings.Unbounded;

   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Active_Value := True;
      Model.Paste_Conflict_Items_Value := Items;
      Model.Paste_Conflict_Existing_Value := Existing;
      Model.Paste_Conflict_Mode_Value := Mode;
      Model.Paste_Conflict_Clears_Clip_Val := Clear_Clipboard;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Index_Value := Index;
      Model.Paste_Conflict_Overrides_Value.Clear;
      for Ignore in Items.First_Index .. Items.Last_Index loop
         Model.Paste_Conflict_Overrides_Value.Append (Files.Paste.Decision_Pending);
      end loop;
   end Begin_Paste_Conflict;

   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Active_Value;
   end Paste_Conflict_Is_Active;

   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Items_Value;
   end Paste_Conflict_Items;

   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Existing_Value;
   end Paste_Conflict_Existing;

   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Overrides_Value;
   end Paste_Conflict_Overrides;

   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy is
   begin
      return Model.Paste_Conflict_Policy_Value;
   end Paste_Conflict_Policy;

   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Conflict_Mode_Value;
   end Paste_Conflict_Mode;

   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Clears_Clip_Val;
   end Paste_Conflict_Clears_Clipboard;

   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Conflict_Index_Value;
   end Paste_Conflict_Index;

   function Paste_Conflict_Name
     (Model : Window_Model)
      return String is
   begin
      if Model.Paste_Conflict_Active_Value
        and then Model.Paste_Conflict_Index_Value
                 in Model.Paste_Conflict_Items_Value.First_Index
                    .. Model.Paste_Conflict_Items_Value.Last_Index
      then
         return To_String
           (Model.Paste_Conflict_Items_Value.Element
              (Model.Paste_Conflict_Index_Value).Dest_Name);
      end if;
      return "";
   end Paste_Conflict_Name;

   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Apply_All_Value;
   end Paste_Conflict_Apply_All;

   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Apply_All_Value := not Model.Paste_Conflict_Apply_All_Value;
   end Toggle_Paste_Conflict_Apply_All;

   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Policy_Value := Policy;
   end Set_Paste_Conflict_Policy;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Index <= Natural (Model.Paste_Conflict_Overrides_Value.Length) then
         Model.Paste_Conflict_Overrides_Value.Replace_Element (Index, Decision);
      end if;
   end Set_Paste_Conflict_Override;

   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Index_Value := Index;
   end Set_Paste_Conflict_Index;

   procedure Clear_Paste_Conflict
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Active_Value := False;
      Model.Paste_Conflict_Items_Value.Clear;
      Model.Paste_Conflict_Existing_Value.Clear;
      Model.Paste_Conflict_Overrides_Value.Clear;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Conflict_Index_Value := 0;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Clears_Clip_Val := True;
   end Clear_Paste_Conflict;

end Paste_Conflict;
