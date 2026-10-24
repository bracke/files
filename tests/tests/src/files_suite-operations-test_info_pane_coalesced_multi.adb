separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Write_File (Join (Root, "alpha.txt"), "aaaa");
      Write_File (Join (Root, "beta.txt"), "bbbb");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "two items are selected");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      --  Wide enough that a short permissions line ("readable, writable") does
      --  not wrap, so the coalesced one-row-per-item layout is what is tested.
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1600, Height => 1200, Line_Height => 20);

      declare
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 1600, Height => 1200, Line_Height => 20);
         Info_Layout : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);

         --  Count the distinct rows a label appears on within the info pane
         --  (the label is drawn twice per row for a faux-bold weight).
         function Label_Rows (Key : String) return Natural is
            Label : constant String := Files.Localization.Text (Key);
            Rows  : Natural := 0;
            Last  : Integer := -1;
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then To_String (Text.Text) = Label
                 and then Integer (Text.Y) /= Last
               then
                  Rows := Rows + 1;
                  Last := Integer (Text.Y);
               end if;
            end loop;
            return Rows;
         end Label_Rows;

         function Value_Present (Value : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X and then To_String (Text.Text) = Value then
                  return True;
               end if;
            end loop;
            return False;
         end Value_Present;

         --  Some info-pane text row ends with the given " (<name>)" postfix.
         function Value_Ends_With (Postfix : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then Length (Text.Text) >= Postfix'Length
                 and then Slice (Text.Text, Length (Text.Text) - Postfix'Length + 1, Length (Text.Text)) = Postfix
               then
                  return True;
               end if;
            end loop;
            return False;
         end Value_Ends_With;

         --  Some info-pane text row contains both substrings.
         function Row_Has_Both (A : String; B : String) return Boolean is
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then Ada.Strings.Fixed.Index (To_String (Text.Text), A) > 0
                 and then Ada.Strings.Fixed.Index (To_String (Text.Text), B) > 0
               then
                  return True;
               end if;
            end loop;
            return False;
         end Row_Has_Both;
      begin
         Assert (Label_Rows ("info.name") = 0, "there is no dedicated Name section");
         Assert (not Value_Present ("alpha.txt") and then not Value_Present ("beta.txt"),
                 "item names appear only as postfixes, not as bare Name rows");
         Assert (Label_Rows ("info.size") = 1, "Size label appears once");
         Assert (Label_Rows ("info.filetype") = 1, "Filetype label appears once");
         Assert (Label_Rows ("info.modified") = 1, "Modified label appears once");
         Assert (Label_Rows ("info.kind") = 0, "the redundant Kind section is removed");
         Assert (Row_Has_Both (Files.Localization.Text ("info.permissions.readable"),
                               Files.Localization.Text ("info.permissions.writable")),
                 "an item's readable and writable permissions share one coalesced row");
         Assert (Value_Ends_With (" (alpha.txt)") and then Value_Ends_With (" (beta.txt)"),
                 "every section row is postfixed with its item name");

         --  No leftover header gap: the first section starts at the pane top.
         declare
            Filetype_Label : constant String := Files.Localization.Text ("info.filetype");
            Top_Y          : Integer := Integer'Last;
         begin
            for Text of Frame.Text loop
               if Text.X >= Info_Layout.X
                 and then To_String (Text.Text) = Filetype_Label
                 and then Integer (Text.Y) < Top_Y
               then
                  Top_Y := Integer (Text.Y);
               end if;
            end loop;
            Assert (Top_Y = Info_Layout.Y + 10,
                    "the first info-pane section starts at the pane top with no reserved header gap");
         end;
      end;
   end Test_Info_Pane_Coalesced_Multi;
