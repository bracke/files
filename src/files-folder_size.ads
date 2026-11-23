with Files.File_System_Types;
with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Real_Time;
with Ada.Strings.Unbounded;

with Files.Jobs.Process;
with Files.Types;

--  Folder-size measurement's values: the directories asked for, the
--  measurements handed back, and the window's session handle, which the
--  model holds as data. Measuring them in a cancellable helper process is
--  the child Files.Folder_Size.Measuring's; this spec reads no disk.
package Files.Folder_Size is

   --  A set of directories to measure (absolute paths).
   package Path_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   --  A directory to measure, and when it was listed as it is now (its
   --  modification time in the listing; Files.Types.Unknown_Time when not
   --  known): a measurement keeps the time its directory was asked for with,
   --  so one taken before the directory changed is told apart from a
   --  current one.
   type Target is record
      Path   : Ada.Strings.Unbounded.Unbounded_String;
      Listed : Ada.Calendar.Time := Files.Types.Unknown_Time;
   end record;

   package Target_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Target);

   --  One window's independent queue and helper ownership
   --  (Files.Folder_Size.Measuring drives it).
   type Session is private;

   --  One finished measurement: Listed is the time its directory was asked
   --  for with (Files.Types.Unknown_Time when the caller gave none).
   type Measurement is record
      Path   : Ada.Strings.Unbounded.Unbounded_String;
      Result : Files.File_System_Types.Directory_Size_Result;
      Listed : Ada.Calendar.Time := Files.Types.Unknown_Time;
   end record;

   package Measurement_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Measurement);

private

   type Session is record
      Job : Files.Jobs.Process.Session;
      --  The running helper's directories, in its order, and the index of
      --  the next result it will publish (result-<index>).
      Batch       : Target_Vectors.Vector;
      Next_Result : Positive := 1;
      --  Steps the next result has failed to open since its helper finished.
      Read_Retries : Natural := 0;
      --  Requested directories not yet given to a helper.
      Targets     : Target_Vectors.Vector;
      Done_Queue  : Measurement_Vectors.Vector;
      Handed_At   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Set_For_Rows      : Natural := Natural'Last;
      Set_For_Selection : Natural := Natural'Last;
   end record;
end Files.Folder_Size;
