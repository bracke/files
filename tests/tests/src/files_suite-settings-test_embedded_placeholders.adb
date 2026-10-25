separate (Files_Suite.Settings)
   procedure Test_Embedded_Placeholders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Lookup    : Files.Settings.Action_Lookup_Result;
      Expanded  : Files.Settings.Open_Action;
   begin
      declare
         Embedded_Args   : Files.Types.String_Vectors.Vector;
         Embedded_Action : Files.Settings.Open_Action;
      begin
         Embedded_Args.Append (To_Unbounded_String ("prefix-{path}"));
         Embedded_Args.Append (To_Unbounded_String ("{stem}.suffix"));
         Embedded_Action := Files.Settings.Make_Action ("inspect", Embedded_Args);
         Expanded := Files.Settings.Expand_Placeholders (Embedded_Action, "/tmp/example/main.ada");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (1)),
            "prefix-{path}",
            "embedded path placeholder remains literal");
         Files_Suite.Support.Assert_Equal
           (To_String (Expanded.Arguments.Element (2)),
            "{stem}.suffix",
            "embedded stem placeholder remains literal");
         Assert
           (Files.Settings.Has_Embedded_Placeholder (Embedded_Action),
            "embedded placeholders are visible to safety checks");
         Assert
           (Files.Settings.Has_Unsafe_Placeholder_Usage (Embedded_Action),
            "embedded placeholders make open actions unsafe");
         Embedded_Action := Files.Settings.Make_Action ("{path}", Files.Types.String_Vectors.Empty_Vector);
         Assert
           (Files.Settings.Has_Unsafe_Placeholder_Usage (Embedded_Action),
            "executable placeholders make open actions unsafe");
      end;
      Assert (Files.Settings.Has_Embedded_Placeholder ("prefix-{path}"), "embedded placeholder is unsafe");
      Assert (not Files.Settings.Has_Embedded_Placeholder ("{path}"), "whole-argument placeholder is safe");
      Assert
        (not Files.Settings.Has_Embedded_Placeholder ("{unknown}"),
         "unknown placeholder token is not treated as a known placeholder");
      Assert
        (not Files.Settings.Has_Embedded_Placeholder ("prefix-{unknown}"),
         "embedded unknown placeholder remains a literal argument");

      Lookup := Files.Settings.Lookup_Open_Action
        (Parsed.Settings,
         "text/unknown-placeholder",
         Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "unknown placeholder open action parses");
      Assert
        (not Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action),
         "unknown placeholder open action is not unsafe");
      Expanded := Files.Settings.Expand_Placeholders (Lookup.Action, "/tmp/example/main.ada");
      Files_Suite.Support.Assert_Equal
        (To_String (Expanded.Arguments.Element (1)),
         "{unknown}",
         "unknown placeholder remains literal after expansion");
   end Test_Embedded_Placeholders;
