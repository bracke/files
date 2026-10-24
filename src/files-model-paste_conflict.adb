separate (Files.Model)
package body Paste_Conflict is

   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Claim_Overlay_Input (Model);
      Model.Paste_Conflict :=
        (Active           => True,
         Items            => Items,
         Existing         => Existing,
         Mode             => Mode,
         Clears_Clipboard => Clear_Clipboard,
         Index            => Index,
         others           => <>);
      for Ignore in Items.First_Index .. Items.Last_Index loop
         Model.Paste_Conflict.Overrides.Append (Files.Paste.Decision_Pending);
      end loop;
   end Begin_Paste_Conflict;

   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict.Active;
   end Paste_Conflict_Is_Active;

   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector is
   begin
      return Model.Paste_Conflict.Items;
   end Paste_Conflict_Items;

   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Conflict.Existing;
   end Paste_Conflict_Existing;

   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector is
   begin
      return Model.Paste_Conflict.Overrides;
   end Paste_Conflict_Overrides;

   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy is
   begin
      return Model.Paste_Conflict.Policy;
   end Paste_Conflict_Policy;

   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Conflict.Mode;
   end Paste_Conflict_Mode;

   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict.Clears_Clipboard;
   end Paste_Conflict_Clears_Clipboard;

   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Conflict.Index;
   end Paste_Conflict_Index;

   function Paste_Conflict_Name
     (Model : Window_Model)
      return String is
   begin
      if Model.Paste_Conflict.Active
        and then Model.Paste_Conflict.Index
                 in Model.Paste_Conflict.Items.First_Index
                    .. Model.Paste_Conflict.Items.Last_Index
      then
         return To_String
           (Model.Paste_Conflict.Items.Element
              (Model.Paste_Conflict.Index).Dest_Name);
      end if;
      return "";
   end Paste_Conflict_Name;

   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict.Apply_All;
   end Paste_Conflict_Apply_All;

   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict.Apply_All := not Model.Paste_Conflict.Apply_All;
   end Toggle_Paste_Conflict_Apply_All;

   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict.Policy := Policy;
   end Set_Paste_Conflict_Policy;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Index <= Natural (Model.Paste_Conflict.Overrides.Length) then
         Model.Paste_Conflict.Overrides.Replace_Element (Index, Decision);
      end if;
   end Set_Paste_Conflict_Override;

   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict.Index := Index;
   end Set_Paste_Conflict_Index;

   procedure Clear_Paste_Conflict
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict := (others => <>);
   end Clear_Paste_Conflict;

end Paste_Conflict;
