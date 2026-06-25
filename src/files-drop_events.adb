with Ada.Strings.Fixed;

package body Files.Drop_Events is
   use Ada.Strings.Unbounded;

   Max_Drop_Paths : constant Positive := 256;

   function Profile return Drop_Event_Source_Profile is
   begin
      return
        (Native_Drop_Callbacks    => True,
         Event_Source_Backend     => True,
         Queued_Drop_Imports      => True,
         Portable_GLFW_Automation => False,
         Requires_OS_Event_Source => False,
         Uses_Shell               => False,
         Max_Paths                => Max_Drop_Paths,
         Binding_Unit             => To_Unbounded_String ("Files.Drop_Events"));
   end Profile;

   procedure Queue
     (Source : in out Drop_Event_Source;
      Paths  : Files.Types.String_Vectors.Vector;
      Mode   : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy) is
   begin
      Source.Pending_Paths.Clear;
      Source.Pending_Mode := Mode;

      for Path of Paths loop
         exit when Natural (Source.Pending_Paths.Length) >= Max_Drop_Paths;

         declare
            Text : constant String := Ada.Strings.Fixed.Trim (To_String (Path), Ada.Strings.Both);
         begin
            if Text'Length > 0 then
               Source.Pending_Paths.Append (To_Unbounded_String (Text));
            end if;
         end;
      end loop;
   end Queue;

   function Has_Pending
     (Source : Drop_Event_Source)
      return Boolean is
   begin
      return not Source.Pending_Paths.Is_Empty;
   end Has_Pending;

   function Pending_Count
     (Source : Drop_Event_Source)
      return Natural is
   begin
      return Natural (Source.Pending_Paths.Length);
   end Pending_Count;

   procedure Take
     (Source : in out Drop_Event_Source;
      Paths  : out Files.Types.String_Vectors.Vector;
      Mode   : out Files.File_System.Drop_Import_Mode) is
   begin
      Paths := Source.Pending_Paths;
      Mode := Source.Pending_Mode;
      Source.Pending_Paths.Clear;
      Source.Pending_Mode := Files.File_System.Drop_Copy;
   end Take;

end Files.Drop_Events;
