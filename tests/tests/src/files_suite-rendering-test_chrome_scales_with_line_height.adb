with Guikit.Layout;

separate (Files_Suite.Rendering)
   --  On a 2x display the line height doubles, and chrome sized in fixed
   --  pixels did not: toolbar buttons half as wide as their text called for,
   --  icons capped at half size, 4-point scrollbars. Chrome now scales with
   --  the line height, and stays as it was at the reference one.
   procedure Test_Chrome_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Reference : constant Positive := Guikit.Layout.Reference_Line_Height;
      Button    : constant Natural := Guikit.Layout.Toolbar_Button_Width;
   begin
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, Reference).Button_Width,
         Guikit.Layout.Toolbar_Button_Width,
         "at the reference line height a toolbar button is as wide as ever");
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, 2 * Reference).Button_Width,
         2 * Guikit.Layout.Toolbar_Button_Width,
         "at twice the line height it is twice as wide");
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, Reference / 2).Button_Width,
         Guikit.Layout.Toolbar_Button_Width,
         "and a small font never shrinks it below the reference size");
      declare
         Doubled : constant Files.Commands.Command_Id :=
           Files.Rendering.Hit.Toolbar_Command_At (3 * Button, 2 * Reference, 2_000, 2 * Reference);
         Single  : constant Files.Commands.Command_Id :=
           Files.Rendering.Hit.Toolbar_Command_At (3 * Button / 2, Reference, 2_000, Reference);
      begin
         Assert (Single /= Files.Commands.No_Command, "the probe is on a toolbar button");
         Assert (Doubled = Single, "the hit test agrees: a point scaled with the display hits the same button");
      end;
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Toolbar_Input_Height (2 * Reference),
         2 * Guikit.Layout.Toolbar_Input_Height (Reference),
         "the toolbar's input fields keep their proportions");
   end Test_Chrome_Scales_With_Line_Height;
