with GNAT.OS_Lib;
with Files.Diagnostics;
with Files.Io_Errors;
with Ada.IO_Exceptions;

with Files.Private_Directories;
with Hostkit.Fs;
with Hostkit.Regular_Files;

package body Files.Exclusive_Streams is
      use type GNAT.OS_Lib.File_Descriptor;

   procedure Create (Stream : in out Output_Stream; Path : String) is
   begin
      if Is_Open (Stream) then
         raise Ada.IO_Exceptions.Status_Error;
      end if;
      Stream.Length := 0;
      Stream.Pending := 0;
      Stream.Descriptor := Hostkit.Regular_Files.Create_New (Path, 8#666#);
      if Stream.Descriptor = GNAT.OS_Lib.Invalid_FD then
         Files.Io_Errors.Capture;
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      begin
         Files.Private_Directories.Make_File_Private (Stream.Descriptor);
      exception
         when others =>
            --  Made exclusively a moment ago, so the file is this call's to
            --  remove: a file it could not make private is not left behind.
            Close_Safely (Stream);
            declare
               --  The failure being raised is the one to report.
               Removed : constant Boolean := Hostkit.Fs.Delete_File (Path);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
            raise;
      end;
   exception
      when others =>
         Close_Safely (Stream);
         raise;
   end Create;

   procedure Close (Stream : in out Output_Stream) is
      Closed : Boolean;
   begin
      if not Is_Open (Stream) then
         return;
      end if;
      begin
         Flush (Stream);
      exception
         when others =>
            Close_Safely (Stream);
            raise Ada.IO_Exceptions.Use_Error;
      end;
      GNAT.OS_Lib.Close (Stream.Descriptor, Closed);
      Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      if not Closed then
         --  A full disk often shows only here, as the data is flushed.
         Files.Io_Errors.Capture;
         raise Ada.IO_Exceptions.Use_Error;
      end if;
   end Close;

   procedure Close_Safely (Stream : in out Output_Stream) is
   begin
      Stream.Pending := 0;
      if Is_Open (Stream) then
         GNAT.OS_Lib.Close (Stream.Descriptor);
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Exclusive_Streams");
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
   end Close_Safely;

   function Is_Open (Stream : Output_Stream) return Boolean is
     (Stream.Descriptor /= GNAT.OS_Lib.Invalid_FD);

   function Size (Stream : Output_Stream) return Long_Long_Integer is
     (Stream.Length);

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
   begin
      if not Is_Open (Stream)
        or else Long_Long_Integer (Item'Length) >
          Long_Long_Integer'Last - Stream.Length
      then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      Files.Descriptor_Streams.Output_Stream (Stream).Write (Item);
      Stream.Length := Stream.Length + Long_Long_Integer (Item'Length);
   end Write;
end Files.Exclusive_Streams;
