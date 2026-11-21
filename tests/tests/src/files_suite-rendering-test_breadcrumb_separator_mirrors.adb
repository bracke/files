with Files.Preference_Types;
with Guikit.Mirroring;
separate (Files_Suite.Rendering)
   --  The breadcrumb separator is a symbol pointing along the path: it is
   --  marked so, and a mirrored frame draws it '<'. A folder named '>' is a
   --  name, drawn as it is.
   procedure Test_Breadcrumb_Separator_Mirrors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap : View_Snapshot := Sample_Snapshot (0, Files.Preference_Types.Details);
   begin
      Snap.Breadcrumb_Segments := Files.Breadcrumbs.Segments ("/home/>/files");
      declare
         Frame      : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Mirrored   : Guikit.Draw.Text_Command_Vectors.Vector := Frame.Text;
         Separators : Natural := 0;
         Names      : Natural := 0;
      begin
         Guikit.Mirroring.Mirror (Mirrored, 1000);
         for Index in Frame.Text.First_Index .. Frame.Text.Last_Index loop
            if To_String (Frame.Text (Index).Text) = ">" then
               if Frame.Text (Index).Mirror_Glyph then
                  Separators := Separators + 1;
                  Assert (To_String (Mirrored (Index).Text) = "<", "a mirrored separator points the other way");
               else
                  Names := Names + 1;
                  Assert (To_String (Mirrored (Index).Text) = ">", "a folder named '>' keeps its name");
               end if;
            end if;
         end loop;
         Assert (Separators >= 2, "the separators between the segments are marked as symbols:" & Separators'Image);
         Assert (Names = 1, "the folder named '>' is drawn as a name:" & Names'Image);
      end;
   end Test_Breadcrumb_Separator_Mirrors;
