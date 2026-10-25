separate (Files_Suite.Interaction)
   procedure Test_Favorite_Stale_Entry_Is_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Stale    : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "gone");
      Before   : constant String := Files.Model.Current_Path (Model);
      Found    : Boolean;
   begin
      Files_Suite.Support.Reset_Root;
      Settings.Favorite_Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Stale));

      Open_Favorites_Selector (Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "the selector opens for the stale-favorite test");

      --  Clicking the stale favorite must not raise and must not navigate.
      Click_Root_Row (Model, Settings, Stale, Found, Result);
      Assert (Found, "the stale favorite row is still laid out");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "a stale favorite click is skipped");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Before,
         "a stale favorite click does not navigate");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "a skipped stale click leaves the selector open");
   end Test_Favorite_Stale_Entry_Is_Skipped;
