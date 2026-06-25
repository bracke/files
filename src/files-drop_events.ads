with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Types;

--  Drop event-source backend shared by native callbacks and automation tests.
package Files.Drop_Events is

   type Drop_Event_Source_Profile is record
      Native_Drop_Callbacks     : Boolean := True;
      Event_Source_Backend      : Boolean := True;
      Queued_Drop_Imports       : Boolean := True;
      Portable_GLFW_Automation  : Boolean := False;
      Requires_OS_Event_Source  : Boolean := False;
      Uses_Shell                : Boolean := False;
      Max_Paths                 : Positive := 256;
      Binding_Unit              : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Drop_Event_Source is private;

   --  Return the active drop event-source backend profile.
   --
   --  @return Structured backend capability metadata.
   function Profile return Drop_Event_Source_Profile;

   --  Queue a drop event, filtering empty path entries and capping path count.
   --
   --  @param Source Drop event source to update.
   --  @param Paths Source paths reported by the native event source.
   --  @param Mode Import mode to apply when the event is drained.
   procedure Queue
     (Source : in out Drop_Event_Source;
      Paths  : Files.Types.String_Vectors.Vector;
      Mode   : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy);

   --  Return whether Source has a queued drop event.
   --
   --  @param Source Drop event source to inspect.
   --  @return True when at least one path is queued.
   function Has_Pending
     (Source : Drop_Event_Source)
      return Boolean;

   --  Return the queued path count.
   --
   --  @param Source Drop event source to inspect.
   --  @return Number of queued source paths.
   function Pending_Count
     (Source : Drop_Event_Source)
      return Natural;

   --  Drain queued paths and clear the source.
   --
   --  @param Source Drop event source to drain.
   --  @param Paths Drained source paths.
   --  @param Mode Drained import mode.
   procedure Take
     (Source : in out Drop_Event_Source;
      Paths  : out Files.Types.String_Vectors.Vector;
      Mode   : out Files.File_System.Drop_Import_Mode);

private
   type Drop_Event_Source is record
      Pending_Paths : Files.Types.String_Vectors.Vector;
      Pending_Mode  : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
   end record;

end Files.Drop_Events;
