with Files.Input_Actions;
with Files.Operation_Results;
with Files.Commands;
with Files.Controller;
with Guikit.Input;
with Files.Types;
with Files.UI_Types;
with Files_Suite.Generic_Assert_Equal;

package Files_Suite.Support is

   --  Record that Test does not run here (a host without the feature it
   --  needs), so a skipped test is counted and named instead of passing in
   --  silence.
   --
   --  @param Test The test routine.
   --  @param Reason The condition that skips it.
   procedure Skip (Test : String; Reason : String);

   --  How many tests skipped so far.
   --
   --  @return The number of Skip calls.
   function Skip_Count return Natural;

   --  Whether a test skipped in this run for a reason.
   --
   --  @param Skip "Test: Reason", the test routine's name and the reason as
   --  passed to Skip -- the form a FILES_TEST_EXPECTED_SKIPS list uses.
   --  @return True when it skipped for that reason.
   function Has_Skipped (Skip : String) return Boolean;

   --  The skips of this run, each "Test: Reason" once, in the order they
   --  first happened.
   --
   --  @return Them.
   function Skips return Files.Types.String_Vectors.Vector;

   --  Assert Actual = Expected; a failure says both values, not only what
   --  was expected to hold.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Integer; Message : String);

   --  As Assert_Equal for sizes and byte counts.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Long_Long_Integer; Message : String);

   --  As Assert_Equal for text.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : String; Message : String);

   --  As Assert_Equal for flags.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Boolean; Message : String);

   --  Assert that the rectangle at X, Y of Width by Height lies inside the
   --  one at Outer_X, Outer_Y of Outer_Width by Outer_Height. Each edge is
   --  its own check, so a failure names the edge that crosses ("left edge",
   --  "top edge", "right edge", "bottom edge") and both coordinates.
   --
   --  @param X Inner left.
   --  @param Y Inner top.
   --  @param Width Inner width.
   --  @param Height Inner height.
   --  @param Outer_X Outer left.
   --  @param Outer_Y Outer top.
   --  @param Outer_Width Outer width.
   --  @param Outer_Height Outer height.
   --  @param Message What the check is about.
   procedure Assert_Inside
     (X, Y, Width, Height                         : Integer;
      Outer_X, Outer_Y, Outer_Width, Outer_Height : Integer;
      Message                                     : String);

   --  Assert that the rectangle at X, Y of Width by Height is not empty and
   --  ends inside a Frame_Width by Frame_Height framebuffer. Each part is its
   --  own check ("width", "height", "right edge", "bottom edge").
   --
   --  @param X Left.
   --  @param Y Top.
   --  @param Width Width, which must be positive.
   --  @param Height Height, which must be positive.
   --  @param Frame_Width Framebuffer width.
   --  @param Frame_Height Framebuffer height.
   --  @param Message What the check is about.
   procedure Assert_Fits
     (X, Y, Width, Height       : Integer;
      Frame_Width, Frame_Height : Integer;
      Message                   : String);

   --  Assert Low <= Value <= High, one check per bound ("below" / "above"),
   --  each saying the value and the bound it crossed.
   --
   --  @param Value Observed value.
   --  @param Low Smallest allowed value.
   --  @param High Largest allowed value.
   --  @param Message What the check is about.
   procedure Assert_Between (Value, Low, High : Float; Message : String);

   --  Assert_Equal for the enumerations the suite compares most.
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Operation_Results.Operation_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Commands.Command_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Controller.Controller_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.UI_Types.Focus_Target);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Guikit.Input.Key_Code);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Input_Actions.Input_Action_Kind);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Color_Label);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Account_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.View_Mode);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Detail_Column);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Sort_Field);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Group_Mode);

end Files_Suite.Support;
