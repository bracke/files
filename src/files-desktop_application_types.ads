with Ada.Containers.Vectors;

with Files.Types;

--  An installed desktop application as the "Open With" picker offers it:
--  a value the model holds (Files.Desktop_Applications finds them and
--  launches one).
package Files.Desktop_Application_Types is
   subtype UString is Files.Types.UString;

   type Application is record
      Name         : UString;
      Exec         : UString;
      Icon         : UString;
      Desktop_File : UString;
      --  Terminal=true: the program runs inside a terminal emulator
      --  (Files.Desktop_Applications.Launch_Actions wraps it in one).
      Terminal     : Boolean := False;
      --  Path=: the folder the entry asks to run in, decoded; empty when it
      --  names none. Files.Desktop_Applications.Launch_Actions hands it to
      --  the launch as its working directory.
      Working_Directory : UString;
   end record;

   package Application_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Application);

end Files.Desktop_Application_Types;
