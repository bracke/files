with Files.Model.Support;
with Ada.Containers.Ordered_Sets;

package body Files.Model.Navigation is
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   function Current_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Current_Path_Value);
   end Current_Path;

   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature is
   begin
      return Model.Directory_Signature;
   end Directory_Signature_Of;

   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Directory_Signature := Signature;
   end Set_Directory_Signature;

   function Home_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Home_Path_Value);
   end Home_Path;

   function Item_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Items.Length);
   end Item_Count;

   function Visible_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      if not Model.Items.Is_Empty then
         for Item of Model.Items loop
            if Item_Is_Visible (Model, Item) then
               Count := Count + 1;
            end if;
         end loop;
      end if;

      if Temporary_Is_Visible (Model) then
         Count := Count + 1;
      end if;

      return Count;
   end Visible_Count;

   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      for Item of Model.Items loop
         declare
            Name : constant String := To_String (Item.Name);
         begin
            if Name'Length > 0 and then Name (Name'First) = '.' then
               Count := Count + 1;
            end if;
         end;
      end loop;

      return Count;
   end Hidden_Item_Count;

   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item
   is
      Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      if Item_Index /= 0 then
         return Model.Items.Element (Positive (Item_Index));
      elsif Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model) then
         if Model.Temporary_Is_Directory then
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Directory_Item);
         else
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "text/plain");
         end if;
      else
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      end if;
   end Visible_Item;

   function Visible_Rows
     (Model : Window_Model)
      return Visible_Row_Vectors.Vector
   is
      package Index_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Natural);

      Filter   : constant String := To_String (Model.Filter_Value);
      Selected : Index_Sets.Set;
      Rows     : Visible_Row_Vectors.Vector;
   begin
      for Item_Index of Model.Selected_Item_Indexes loop
         Selected.Include (Item_Index);
      end loop;

      if not Model.Items.Is_Empty then
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            declare
               Item : constant Files.File_System.Directory_Item := Model.Items.Element (Index);
            begin
               if Filter = ""
                 or else Files.Types.Contains_Case_Insensitive (To_String (Item.Name), Filter)
               then
                  Rows.Append
                    (Visible_Row'(Item     => Item,
                                  Selected => Selected.Contains (Natural (Index))));
               end if;
            end;
         end loop;
      end if;

      if Temporary_Is_Visible (Model) then
         declare
            Temp : constant Files.File_System.Directory_Item :=
              (if Model.Temporary_Is_Directory then
                  Files.File_System.Make_Item
                    (Parent_Path => Current_Path (Model),
                     Name        => To_String (Model.Temporary_Name_Value),
                     Kind        => Files.Types.Directory_Item)
               else
                  Files.File_System.Make_Item
                    (Parent_Path => Current_Path (Model),
                     Name        => To_String (Model.Temporary_Name_Value),
                     Kind        => Files.Types.Regular_File_Item,
                     Filetype    => "text/plain"));
         begin
            Rows.Append
              (Visible_Row'(Item     => Temp,
                            Selected => Selected.Contains (Temporary_Item_Index)));
         end;
      end if;

      return Rows;
   end Visible_Rows;

   function In_Recent_View
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Recent_View_Active;
   end In_Recent_View;

   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Path /= "" then
         Model.Recent_Open_Queue.Append (To_Unbounded_String (Path));
      end if;
   end Note_Recent_Open;

   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Drained : constant Files.Types.String_Vectors.Vector := Model.Recent_Open_Queue;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Recent_Open_Queue.Clear;
      return Drained;
   end Take_Recent_Opens;

   function Can_Go_Back
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Back_History.Is_Empty;
   end Can_Go_Back;

   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Forward_History.Is_Empty;
   end Can_Go_Forward;

end Files.Model.Navigation;
