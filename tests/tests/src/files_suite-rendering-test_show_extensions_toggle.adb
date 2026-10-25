separate (Files_Suite.Rendering)
   procedure Test_Show_Extensions_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Has_Text (Frame : Frame_Commands; S : String) return Boolean is
      begin
         for Cmd of Frame.Text loop
            if To_String (Cmd.Text) = S then
               return True;
            end if;
         end loop;
         return False;
      end Has_Text;

      function Rendered (Name : String; Kind : Files.Types.Item_Kind; Show_Ext : Boolean) return Frame_Commands is
         Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
         Item     : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Name := To_Unbounded_String (Name);
         Item.Kind := Kind;
         Snapshot.Items.Replace_Element (1, Item);
         Snapshot.Show_Extensions := Show_Ext;
         return Build_Frame_Commands (Snapshot, 1000, 800, 20);
      end Rendered;
   begin
      Assert (Has_Text (Rendered ("readme.txt", Files.Types.Regular_File_Item, True), "readme.txt"),
              "with extensions on the full name is shown");

      declare
         Frame : constant Frame_Commands := Rendered ("readme.txt", Files.Types.Regular_File_Item, False);
      begin
         Assert (Has_Text (Frame, "readme"), "with extensions off the trailing extension is dropped");
         Assert (not Has_Text (Frame, "readme.txt"), "with extensions off the full name is not drawn");
      end;

      --  A name that is only a leading-dot extension keeps its whole name.
      Assert (Has_Text (Rendered (".bashrc", Files.Types.Regular_File_Item, False), ".bashrc"),
              "a dotfile stays fully visible with extensions off");

      --  Directory names are never stripped, even when they contain a dot.
      Assert (Has_Text (Rendered ("my.folder", Files.Types.Directory_Item, False), "my.folder"),
              "a folder keeps its dotted name with extensions off");
   end Test_Show_Extensions_Toggle;
