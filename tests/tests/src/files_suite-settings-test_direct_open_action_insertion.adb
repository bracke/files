separate (Files_Suite.Settings)
   procedure Test_Direct_Open_Action_Insertion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Manual    : Files.Settings.Settings_Model := Settings_With_Direct_Mappings;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Lookup    : Files.Settings.Action_Lookup_Result;
      Args      : Files.Types.String_Vectors.Vector;
   begin
      Args.Append (To_Unbounded_String ("{path}"));
      Files.Settings.Add_Open_Action
        (Manual,
         "text/manual+META+shift+alt+control+shift",
         Files.Settings.Make_Action ("first", Args));
      Files.Settings.Add_Open_Action
        (Manual,
         " text/manual+control+alt+meta+shift ",
         Files.Settings.Make_Action ("second", Args));
      Files.Settings.Add_Open_Action
        (Manual,
         " text/spaced-manual + META + shift ",
         Files.Settings.Make_Action (" spaced-manual ", Args));
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Modifiers (Guikit.Input.Alt_Key) := True;
      Modifiers (Guikit.Input.Control_Key) := True;
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Modifier_Token (Modifiers),
         "+shift+control+alt+meta",
         "modifier tokens are emitted in stable lookup order");
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion normalizes modifiers");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/manual+shift+control+alt+meta",
         "direct open-action lookup reports normalized modifier token");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "second",
         "direct open-action insertion replaces normalized duplicate token");
      Modifiers := Guikit.Input.No_Modifiers;
      Modifiers (Guikit.Input.Meta_Key) := True;
      Modifiers (Guikit.Input.Shift_Key) := True;
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/spaced-manual", Modifiers);
      Assert (Lookup.Found, "direct open-action insertion trims filetype before modifiers");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "text/spaced-manual+shift+meta",
         "direct spaced open-action token is normalized");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Executable),
         "spaced-manual",
         "direct open-action insertion trims executable whitespace");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Action.Arguments.Element (1)),
         "{path}",
         "direct open-action insertion preserves argument values");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores dangling modifier separator");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+control+",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/bad-direct",
         [Guikit.Input.Control_Key => True, others => False]);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores trailing modifier separator after a modifier");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+control++alt",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action
        (Manual,
         "text/bad-direct",
         [Guikit.Input.Control_Key => True, Guikit.Input.Alt_Key => True, others => False]);
      Assert
        (not Lookup.Found,
         "direct open-action insertion ignores empty modifier segments");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad-direct+custom",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad-direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unknown modifiers");
      Files.Settings.Add_Open_Action
        (Manual,
         "image/svg+xml",
         Files.Settings.Make_Action ("svg-viewer", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "image/svg+xml", Guikit.Input.No_Modifiers);
      Assert (Lookup.Found, "direct open-action insertion accepts structured filetype suffixes");
      Files_Suite.Support.Assert_Equal
        (To_String (Lookup.Token),
         "image/svg+xml",
         "direct structured filetype suffix lookup keeps plus suffix");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/bad=direct",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/bad=direct", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores unrepresentable filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         """text/quoted-direct""",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, """text/quoted-direct""", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores quoted filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         "[text/bracketed-direct]",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "[text/bracketed-direct]", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores bracketed filetype keys");
      Files.Settings.Add_Open_Action
        (Manual,
         "+control",
         Files.Settings.Make_Action ("bad", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "", Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores modifier-only token");
      Files.Settings.Add_Open_Action
        (Manual,
         "text/empty-executable",
         Files.Settings.Make_Action ("   ", Args));
      Lookup := Files.Settings.Lookup_Open_Action (Manual, "text/empty-executable", Guikit.Input.No_Modifiers);
      Assert (not Lookup.Found, "direct open-action insertion ignores empty executable");
   end Test_Direct_Open_Action_Insertion;
