separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Word_Wrap (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      Reset_Root;
      Write_Info_Metadata_Fixtures;
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);

      declare
         Narrow_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
         Narrow_Info     : Files.Rendering.Info_Snapshot :=
           Narrow_Snapshot.Selected_Info.Element (1);
         Narrow_Frame    : Files.Rendering.Frame_Commands;
         Found_First     : Boolean := False;
         Found_Second    : Boolean := False;
         Found_Broken    : Boolean := False;
      begin
         Narrow_Info.Filetype_Extra :=
           To_Unbounded_String ("Markdown document has 233 lines.");
         Narrow_Snapshot.Selected_Info.Replace_Element (1, Narrow_Info);
         Narrow_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Narrow_Snapshot, Width => 640, Height => 800, Line_Height => 20);

         for Text of Narrow_Frame.Text loop
            Found_First :=
              Found_First or else To_String (Text.Text) = "Markdown document has";
            Found_Second := Found_Second or else To_String (Text.Text) = "233 lines.";
            Found_Broken :=
              Found_Broken
              or else To_String (Text.Text) = "Markdown document has 2"
              or else To_String (Text.Text) = "33 lines.";
         end loop;

         Assert (Found_First, "info metadata wraps at word boundaries instead of splitting words: first line");
         Assert (Found_Second, "info metadata wraps at word boundaries instead of splitting words: second line");
         Assert (not Found_Broken, "info metadata wraps at word boundaries instead of splitting words: no split word");
      end;
   end Test_Info_Pane_Word_Wrap;
