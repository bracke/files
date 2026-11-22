with Files.Item_Lists;
with Files.Model.Creation;
separate (Files_Suite.Model)
   procedure Test_Temporary_Row_Encoding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Rows     : Natural := 0;
      Zero     : Natural := 0;
      Last     : Natural := 0;
      Fields   : Natural := 0;
      Field_At : Natural := 0;

      procedure Visit (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
         pragma Unreferenced (Item);
      begin
         Rows := Rows + 1;
         Last := Item_Index;
         if Item_Index = 0 then
            Zero := Zero + 1;
         end if;
         Assert (Selected = (Item_Index = Files.Model.Temporary_Item_Index),
                 "only the pending create row is selected");
      end Visit;

      procedure Field (Item_Index : Natural; Value : Ada.Strings.Unbounded.Unbounded_String; Cursor : Natural) is
         pragma Unreferenced (Value, Cursor);
      begin
         Fields := Fields + 1;
         Field_At := Item_Index;
      end Field;
   begin
      Reset_Root;
      Write_File (Join (Root, "a.txt"));
      Write_File (Join (Root, "b.txt"));
      Items.Append (Files.Item_Lists.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.Item_Lists.Make_Item (Root, "b.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert (Files.Model.Creation.Temporary_Item_Is_Active (Model), "create adds the pending row");

      Files.Model.For_Each_Visible_Row (Model, Visit'Access);
      Files_Suite.Support.Assert_Equal (Rows, 3, "two items and the pending row are visible");
      Files_Suite.Support.Assert_Equal (Zero, 0, "no visible row is named by index 0");
      Files_Suite.Support.Assert_Equal
        (Last, Files.Model.Temporary_Item_Index, "the pending row is Temporary_Item_Index");

      Files.Model.Rename.For_Each_Field (Model, Field'Access);
      Files_Suite.Support.Assert_Equal (Fields, 1, "one rename field edits the pending row");
      Files_Suite.Support.Assert_Equal
        (Field_At, Files.Model.Temporary_Item_Index, "the pending row's rename field is Temporary_Item_Index");

      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Rows (Model).Last_Element.Item_Index,
         Files.Model.Temporary_Item_Index,
         "Visible_Rows names the pending row by Temporary_Item_Index");
      Files_Suite.Support.Assert_Equal
        (Result.Command, Files.Commands.Create_File_Command, "create ran as the create command");
   end Test_Temporary_Row_Encoding;
