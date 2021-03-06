%Module(name=qgis._core,
        keyword_arguments="All")

%ModuleCode

#include "qgsexception.h"

QString getTraceback()
{
#define TRACEBACK_FETCH_ERROR(what) {errMsg = what; goto done;}

  // acquire global interpreter lock to ensure we are in a consistent state
  PyGILState_STATE gstate;
  gstate = PyGILState_Ensure();

  QString errMsg;
  QString result;

  PyObject *modStringIO = nullptr;
  PyObject *modTB = nullptr;
  PyObject *obStringIO = nullptr;
  PyObject *obResult = nullptr;

  PyObject *type, *value, *traceback;

  PyErr_Fetch( &type, &value, &traceback );
  PyErr_NormalizeException( &type, &value, &traceback );

  const char *iomod = "io";

  modStringIO = PyImport_ImportModule( iomod );
  if ( !modStringIO )
    TRACEBACK_FETCH_ERROR( QString( "can't import %1" ).arg( iomod ) );

  obStringIO = PyObject_CallMethod( modStringIO, ( char * ) "StringIO", nullptr );

  /* Construct a cStringIO object */
  if ( !obStringIO )
    TRACEBACK_FETCH_ERROR( "cStringIO.StringIO() failed" );

  modTB = PyImport_ImportModule( "traceback" );
  if ( !modTB )
    TRACEBACK_FETCH_ERROR( "can't import traceback" );

  obResult = PyObject_CallMethod( modTB, ( char * ) "print_exception",
                                  ( char * ) "OOOOO",
                                  type, value ? value : Py_None,
                                  traceback ? traceback : Py_None,
                                  Py_None,
                                  obStringIO );

  if ( !obResult )
    TRACEBACK_FETCH_ERROR( "traceback.print_exception() failed" );

  Py_DECREF( obResult );

  obResult = PyObject_CallMethod( obStringIO, ( char * ) "getvalue", nullptr );
  if ( !obResult )
    TRACEBACK_FETCH_ERROR( "getvalue() failed." );

  /* And it should be a string all ready to go - duplicate it. */
  if ( !PyUnicode_Check( obResult ) )
    TRACEBACK_FETCH_ERROR( "getvalue() did not return a string" );

  result = QString::fromUtf8( PyUnicode_AsUTF8( obResult ) );

done:

  // All finished - first see if we encountered an error
  if ( result.isEmpty() && !errMsg.isEmpty() )
  {
    result = errMsg;
  }

  Py_XDECREF( modStringIO );
  Py_XDECREF( modTB );
  Py_XDECREF( obStringIO );
  Py_XDECREF( obResult );
  Py_XDECREF( value );
  Py_XDECREF( traceback );
  Py_XDECREF( type );

  // we are done calling python API, release global interpreter lock
  PyGILState_Release( gstate );

  return result;
}

%End

%Import QtXml/QtXmlmod.sip
%Import QtNetwork/QtNetworkmod.sip
%Import QtSql/QtSqlmod.sip

%Import QtPrintSupport/QtPrintSupportmod.sip
%Import QtWidgets/QtWidgetsmod.sip

%Feature ANDROID

%Include conversions.sip
%Include qgsexception.sip
%Include typedefs.sip

%Include core_auto.sip

%VirtualErrorHandler processing_exception_handler
    throw QgsProcessingException( getTraceback() );
%End
