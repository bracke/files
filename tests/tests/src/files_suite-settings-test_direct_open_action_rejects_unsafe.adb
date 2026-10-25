separate (Files_Suite.Settings)
   procedure Test_Direct_Open_Action_Rejects_Unsafe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual : Files.Settings.Settings_Model := Settings_With_Direct_Insertions;
      Lookup : Files.Settings.Action_Lookup_Result;
      Args   : Files.Types.String_Vectors.Vector;
   begin
      Args.Append (To_Unbounded_String ("{path}"));
      declare
         Unsafe_Args : Files.Types.String_Vectors.Vector;
      begin
         Unsafe_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/unsafe-argument",
            Files.Settings.Make_Action ("unsafe", Unsafe_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-argument", Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores embedded placeholders");
      end;
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unsafe-executable",
         Files.Settings.Make_Action ("{path}", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/unsafe-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable placeholders");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/linebreak-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.LF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/nul-executable",
         Files.Settings.Make_Action
           ("viewer" & Character'Val (0) & "ignored", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual, "text/nul-executable", Guikit.Input.No_Modifiers);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores NUL-containing executables");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/formfeed-executable",
         Files.Settings.Make_Action ("viewer" & ASCII.FF & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/formfeed-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable form feeds");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/c1break-executable",
         Files.Settings.Make_Action ("viewer" & C1_Break & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores executable C1 line breaks");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Files.Settings.Make_Action ("viewer" & Line_Separator & "bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/unicodebreak-executable",
         Guikit.Input.No_Modifiers);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores executable Unicode line separators");
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & ASCII.LF & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/linebreak-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/linebreak-argument", Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument line breaks");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append
           (To_Unbounded_String ("arg" & Character'Val (0) & "ignored"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/nul-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action
           (Manual, "text/nul-argument", Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "direct open-action insertion ignores NUL-containing arguments");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & ASCII.VT & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/vtab-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/vtab-argument", Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument vertical tabs");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & C1_Break & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/c1break-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/c1break-argument", Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "direct open-action insertion ignores argument C1 line breaks");
      end;
      declare
         Broken_Args : Files.Types.String_Vectors.Vector;
      begin
         Broken_Args.Append (To_Unbounded_String ("arg" & Line_Separator & "bad"));
         Files.Settings.Add_Open_Action
           (Manual,
            "text/unicodebreak-argument",
            Files.Settings.Make_Action ("viewer", Broken_Args));
         Lookup := Files.Settings.Lookup_Open_Action
           (Manual,
            "text/unicodebreak-argument",
            Guikit.Input.No_Modifiers);
         Assert
           (not Lookup.Found,
            "direct open-action insertion ignores argument Unicode line separators");
      end;
   end Test_Direct_Open_Action_Rejects_Unsafe;
