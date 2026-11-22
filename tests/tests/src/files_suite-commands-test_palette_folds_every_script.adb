with Files.Desktop_Applications;
with Files.Model.Command_Palette;
with Files.Overlays.Command_Palette;
separate (Files_Suite.Commands)
   --  The palette files opens folds case the way the filter bar does, in
   --  every script: guikit's own folding knows ASCII and Latin-1 only, so
   --  a Greek or Cyrillic query typed in lower case finds a capitalised
   --  name only through the folding files hands it.
   procedure Test_Palette_Folds_Every_Script (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  "Ωμέγα" and "Редактор", capitalised, in UTF-8.
      Greek    : constant String :=
        Character'Val (16#CE#) & Character'Val (16#A9#) & Character'Val (16#CE#) & Character'Val (16#BC#)
        & Character'Val (16#CE#) & Character'Val (16#AD#) & Character'Val (16#CE#) & Character'Val (16#B3#)
        & Character'Val (16#CE#) & Character'Val (16#B1#);
      Cyrillic : constant String :=
        Character'Val (16#D0#) & Character'Val (16#A0#) & Character'Val (16#D0#) & Character'Val (16#B5#)
        & Character'Val (16#D0#) & Character'Val (16#B4#) & Character'Val (16#D0#) & Character'Val (16#B0#)
        & Character'Val (16#D0#) & Character'Val (16#BA#);
      --  The same words' first letters in lower case: "ω" and "р".
      Greek_Query    : constant String :=
        Character'Val (16#CF#) & Character'Val (16#89#) & Character'Val (16#CE#) & Character'Val (16#BC#);
      Cyrillic_Query : constant String :=
        Character'Val (16#D1#) & Character'Val (16#80#) & Character'Val (16#D0#) & Character'Val (16#B5#);
      Model        : Files.Model.Window_Model;
      Targets      : Files.Types.String_Vectors.Vector;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector;

      procedure Expect (Query : String; Name : String) is
      begin
         Files.Model.Command_Palette.Set_Query (Model, Query);
         Files.Overlays.Command_Palette.Ensure_Listed (Model);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Command_Palette.Result_Count (Model), 1, Name & ": the lower-case query finds it");
      end Expect;
   begin
      Targets.Append (To_Unbounded_String ("/sample/file"));
      Applications.Append
        (Files.Desktop_Applications.Application'
           (Name => To_Unbounded_String (Greek & " Viewer"), Exec => To_Unbounded_String ("viewer %f"), others => <>));
      Applications.Append
        (Files.Desktop_Applications.Application'
           (Name => To_Unbounded_String (Cyrillic & " Edit"), Exec => To_Unbounded_String ("edit %f"), others => <>));
      Files.Model.Initialize (Model, "/sample", Files.Items.Item_Vectors.Empty_Vector, "/sample");
      Files.Model.Command_Palette.Open_With (Model, Targets, Applications);
      Files.Overlays.Command_Palette.Ensure_Listed (Model);
      Expect (Greek_Query, "a Greek name");
      Expect (Cyrillic_Query, "a Cyrillic name");
   end Test_Palette_Folds_Every_Script;
