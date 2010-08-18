!    CALL ENTERS( "FieldmlUtil_CreateLayoutParameters", err, errorString, *999 )
!    CALL EXITS( "FieldmlUtil_CreateLayoutParameters" )
!    RETURN
!999 CALL ERRORS( "FieldmlUtil_CreateLayoutParameters", err, errorString )
!    CALL EXITS( "FieldmlUtil_CreateLayoutParameters" )
!    RETURN 1
!> \file
!> $Id$
!> \author Caton Little
!> \brief This module handles reading in FieldML files.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> Input routines for FieldML

MODULE FIELDML_INPUT_ROUTINES

  USE FIELDML_API
  USE FIELDML_UTIL_ROUTINES
  USE OPENCMISS
  USE UTIL_ARRAY
  USE CMISS

  IMPLICIT NONE

  PRIVATE

  !Module parameters
  INTEGER(INTG), PARAMETER :: BUFFER_SIZE = 1024

  INTEGER(INTG), PARAMETER :: FML_ERR_UNKNOWN_BASIS = 10001
  INTEGER(INTG), PARAMETER :: FML_ERR_INVALID_BASIS = 10002
  INTEGER(INTG), PARAMETER :: FML_ERR_UNKNOWN_MESH_XI = 10003
  INTEGER(INTG), PARAMETER :: FML_ERR_UNKNOWN_COORDINATE_TYPE = 10004
  INTEGER(INTG), PARAMETER :: FML_ERR_INVALID_PARAMETER = 10007
  INTEGER(INTG), PARAMETER :: FML_ERR_INVALID_MESH = 10008
  INTEGER(INTG), PARAMETER :: FML_ERR_INVALID_CONNECTIVITY = 10009

  CHARACTER(KIND=C_CHAR), PARAMETER :: NUL = C_NULL_CHAR

  TYPE(VARYING_STRING) :: errorString


  !Interfaces

  INTERFACE

  END INTERFACE

  PUBLIC :: FieldmlInput_InitializeFromFile, FieldmlInput_SetDofVariables, FieldmlInput_GetMeshInfo, &
    & FieldmlInput_GetCoordinateSystemInfo, FieldmlInput_CreateBasis, FieldmlInput_CreateMeshComponent, &
    & FieldmlInput_CreateField

CONTAINS

  !
  !================================================================================================================================
  !
  
  SUBROUTINE FieldmlInput_GetBasisConnectivityInfo( fmlHandle, meshHandle, basisHandle, connectivityHandle, layoutHandle, err, * )
    !Argument variables
    TYPE(C_PTR), INTENT(IN) :: fmlHandle !<The FieldML handle
    INTEGER(C_INT), INTENT(IN) :: meshHandle
    INTEGER(C_INT), INTENT(IN) :: basisHandle
    INTEGER(C_INT), INTENT(OUT) :: connectivityHandle
    INTEGER(C_INT), INTENT(OUT) :: layoutHandle
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    
    !Local variables
    INTEGER(C_INT) :: count, i, xiHandle, paramsHandle, handle1, handle2
    
    CALL ENTERS( "FieldmlInput_GetBasisConnectivityInfo", err, errorString, *999 )

    count = Fieldml_GetAliasCount( fmlHandle, basisHandle )
    IF( count /= 2 ) THEN
      err = FML_ERR_INVALID_BASIS
      CALL FieldmlUtil_CheckError( "Library basis evaluators must have exactly two domain aliases", err, errorString, *999 )
    END IF
    
    xiHandle = Fieldml_GetMeshXiDomain( fmlHandle, meshHandle )
    CALL FieldmlUtil_CheckError( "Cannot get mesh xi domain", fmlHandle, errorString, *999 )

    handle1 = Fieldml_GetAliasLocal( fmlHandle, basisHandle, 1 )
    CALL FieldmlUtil_CheckError( "Cannot get first alias for FEM evaluator", fmlHandle, errorString, *999 )
    handle2 = Fieldml_GetAliasLocal( fmlHandle, basisHandle, 2 )
    CALL FieldmlUtil_CheckError( "Cannot get second alias for FEM evaluator", fmlHandle, errorString, *999 )

    IF( handle1 == xiHandle ) THEN
      paramsHandle = handle2
    ELSE IF( handle2 == xiHandle ) THEN
      paramsHandle = handle1
    ELSE
      err = FML_ERR_INVALID_BASIS
      CALL FieldmlUtil_CheckError( "Library FEM evaluators must a xi alias", err, errorString, *999 )
    ENDIF

    IF( Fieldml_GetObjectType( fmlHandle, paramsHandle ) /= FHT_CONTINUOUS_REFERENCE ) THEN
      err = FML_ERR_INVALID_BASIS
      CALL FieldmlUtil_CheckError( "Parameter evaluator for interpolator must be a reference", err, errorString, *999 )
    ENDIF
    
    count = Fieldml_GetAliasCount( fmlHandle, paramsHandle )
    IF( count /= 1 ) THEN
      err = FML_ERR_INVALID_BASIS
      CALL FieldmlUtil_CheckError( "Nodal parameter evaluator must only have one aliased domain", err, errorString, *999 )
    ENDIF

    handle1 = Fieldml_GetAliasLocal( fmlHandle, paramsHandle, 1 )
    CALL FieldmlUtil_CheckError( "Cannot get connectivity source for nodal parameters", fmlHandle, errorString, *999 )
    
    count = Fieldml_GetMeshConnectivityCount( fmlHandle, meshHandle )
    CALL FieldmlUtil_CheckError( "Cannot get mesh connectivity count", fmlHandle, errorString, *999 )
    DO i = 1, count
      IF( Fieldml_GetMeshConnectivitySource( fmlHandle, meshHandle, i ) == handle1 ) THEN
        connectivityHandle = handle1
        layoutHandle = Fieldml_GetMeshConnectivityDomain( fmlHandle, meshHandle, i )
        RETURN
      ENDIF
    ENDDO

    err = FML_ERR_INVALID_BASIS
    CALL FieldmlUtil_CheckError( "Cannot find connectivity for given basis", err, errorString, *999 )

    CALL EXITS( "FieldmlInput_GetBasisConnectivityInfo" )
    RETURN
999 CALL ERRORS( "FieldmlInput_GetBasisConnectivityInfo", err, errorString )
    CALL EXITS( "FieldmlInput_GetBasisConnectivityInfo" )
    RETURN 1

  END SUBROUTINE FieldmlInput_GetBasisConnectivityInfo

  !
  !================================================================================================================================
  !
  
  SUBROUTINE FieldmlInput_GetBasisCollapse( name, collapse )
    !Argument variables
    CHARACTER(LEN=*), INTENT(IN) :: name
    INTEGER(INTG), ALLOCATABLE, INTENT(INOUT) :: collapse(:)

    collapse = CMISSBasisNotCollapsed
    
    IF( SIZE( collapse ) > 0 ) THEN
      IF( INDEX( name, "_xi1C" ) /= 0 ) THEN
        collapse(1) = CMISSBasisXiCollapsed
      ELSE IF( INDEX( name, "_xi10" ) /= 0 ) THEN
        collapse(1) = CMISSBasisCollapsedAtXi0
      ELSE IF( INDEX( name, "_xi11" ) /= 0 ) THEN
        collapse(1) = CMISSBasisCollapsedAtXi1
      ENDIF
    ENDIF
  
    IF( SIZE( collapse ) > 1 ) THEN
      IF( INDEX( name, "_xi2C" ) /= 0 ) THEN
        collapse(2) = CMISSBasisXiCollapsed
      ELSE IF( INDEX( name, "_xi20" ) /= 0 ) THEN
        collapse(2) = CMISSBasisCollapsedAtXi0
      ELSE IF( INDEX( name, "_xi21" ) /= 0 ) THEN
        collapse(2) = CMISSBasisCollapsedAtXi1
      ENDIF
    ENDIF
  
    IF( SIZE( collapse ) > 2 ) THEN
      IF( INDEX( name, "_xi3C" ) /= 0 ) THEN
        collapse(3) = CMISSBasisXiCollapsed
      ELSE IF( INDEX( name, "_xi30" ) /= 0 ) THEN
        collapse(3) = CMISSBasisCollapsedAtXi0
      ELSE IF( INDEX( name, "_xi31" ) /= 0 ) THEN
        collapse(3) = CMISSBasisCollapsedAtXi1
      ENDIF
    ENDIF
  
  END SUBROUTINE

  !
  !================================================================================================================================
  !

  SUBROUTINE FieldmlInput_GetBasisInfo( fmlInfo, objectHandle, basisType, basisInterpolations, collapse, err, * )
    !Argument variables
    TYPE(FieldmlInfoType), INTENT(IN) :: fmlInfo
    INTEGER(C_INT), INTENT(IN) :: objectHandle
    INTEGER(INTG), INTENT(OUT) :: basisType
    INTEGER(INTG), ALLOCATABLE, INTENT(OUT) :: basisInterpolations(:)
    INTEGER(INTG), ALLOCATABLE, INTENT(OUT) :: collapse(:)
    INTEGER(INTG), INTENT(OUT) :: err

    !Locals
    INTEGER(C_INT) :: length, connectivityHandle, layoutHandle, libraryBasisHandle
    CHARACTER(LEN=BUFFER_SIZE) :: name
    
    CALL ENTERS( "FieldmlInput_GetBasisInfo", err, errorString, *999 )

    IF( .NOT. FieldmlInput_IsKnownBasis( fmlInfo%fmlHandle, fmlInfo%meshHandle, objectHandle, err ) ) THEN
      CALL FieldmlUtil_CheckError( "Basis specified in FieldML file is not yet supported", err, errorString, *999 )
    ENDIF

    IF( Fieldml_GetObjectType( fmlInfo%fmlHandle, objectHandle ) /= FHT_CONTINUOUS_REFERENCE ) THEN
      err = FML_ERR_INVALID_BASIS
      CALL FieldmlUtil_CheckError( "Basis evaluator must be a continuous reference", err, errorString, *999 )
    ENDIF
    
    libraryBasisHandle = Fieldml_GetReferenceRemoteEvaluator( fmlInfo%fmlHandle, objectHandle )
    CALL FieldmlUtil_CheckError( "Basis specified in FieldML is not a reference evaluator", fmlInfo, errorString, *999 )
    length = Fieldml_CopyObjectName( fmlInfo%fmlHandle, libraryBasisHandle, name, BUFFER_SIZE )
    CALL FieldmlUtil_CheckError( "Cannot get name of basis evaluator", fmlInfo, errorString, *999 )

    IF( INDEX( name, 'library.fem.triquadratic_lagrange') == 1 ) THEN
      CALL REALLOCATE_INT( basisInterpolations, 3, "", err, errorString, *999 )
      CALL REALLOCATE_INT( collapse, 3, "", err, errorString, *999 )
      basisInterpolations = CMISSBasisQuadraticLagrangeInterpolation
      basisType = CMISSBasisLagrangeHermiteTPType
    ELSE IF( INDEX( name, 'library.fem.trilinear_lagrange') == 1 ) THEN
      CALL REALLOCATE_INT( basisInterpolations, 3, "", err, errorString, *999 )
      CALL REALLOCATE_INT( collapse, 3, "", err, errorString, *999 )
      basisInterpolations = CMISSBasisLinearLagrangeInterpolation
      basisType = CMISSBasisLagrangeHermiteTPType
    ELSE
      err = FML_ERR_UNKNOWN_BASIS
      CALL FieldmlUtil_CheckError( "Basis cannot yet be interpreted", err, errorString, *999 )
    ENDIF
    
    IF( basisType == CMISSBasisLagrangeHermiteTPType ) THEN
      CALL FieldmlInput_GetBasisCollapse( name(1:length), collapse )
    ENDIF
    
    CALL FieldmlInput_GetBasisConnectivityInfo( fmlInfo%fmlHandle, fmlInfo%meshHandle, objectHandle, connectivityHandle, &
      & layoutHandle, err, *999 )

    CALL EXITS( "FieldmlInput_GetBasisInfo" )
    RETURN
999 CALL ERRORS( "FieldmlInput_GetBasisInfo", err, errorString )
    CALL EXITS( "FieldmlInput_GetBasisInfo" )
    RETURN 1

  END SUBROUTINE FieldmlInput_GetBasisInfo

  !
  !================================================================================================================================
  !

  FUNCTION FieldmlInput_IsKnownBasis( fmlHandle, meshHandle, objectHandle, err )
    !Argument variables
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: meshHandle
    INTEGER(C_INT), INTENT(IN) :: objectHandle
    INTEGER(INTG), INTENT(OUT) :: err
    
    !Function
    LOGICAL :: FieldmlInput_IsKnownBasis

    !Locals
    INTEGER(C_INT) :: length, connectivityHandle, layoutHandle, libraryBasisHandle
    CHARACTER(LEN=BUFFER_SIZE) :: name
    
    FieldmlInput_IsKnownBasis = .FALSE.

    IF( Fieldml_GetObjectType( fmlHandle, objectHandle ) /= FHT_CONTINUOUS_REFERENCE ) THEN
      err = FML_ERR_INVALID_BASIS
      RETURN
    ENDIF

    libraryBasisHandle = Fieldml_GetReferenceRemoteEvaluator( fmlHandle, objectHandle )
    length = Fieldml_CopyObjectName( fmlHandle, libraryBasisHandle, name, BUFFER_SIZE )

    IF( ( INDEX( name, 'library.fem.triquadratic_lagrange') /= 1 ) .AND. &
      & ( INDEX( name, 'library.fem.trilinear_lagrange') /= 1 ) ) THEN
      err = FML_ERR_UNKNOWN_BASIS
      RETURN
    ENDIF
    
    CALL FieldmlInput_GetBasisConnectivityInfo( fmlHandle, meshHandle, objectHandle, connectivityHandle, layoutHandle, err, *999 )
    IF( connectivityHandle == FML_INVALID_HANDLE ) THEN
      err = FML_ERR_INVALID_BASIS
      RETURN
    ENDIF
    
    FieldmlInput_IsKnownBasis = .TRUE.
    RETURN

    err = FML_ERR_INVALID_BASIS
999 RETURN
    
  END FUNCTION FieldmlInput_IsKnownBasis
  
  !
  !================================================================================================================================
  !

  FUNCTION FieldmlInput_HasMarkup( fmlHandle, object, attribute, value, err )
    !Arguments
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: object
    CHARACTER(LEN=*), INTENT(IN) :: attribute
    CHARACTER(LEN=*), INTENT(IN) :: value
    INTEGER(INTG), INTENT(OUT) :: err

    LOGICAL :: FieldmlInput_HasMarkup

    !Locals
    INTEGER(C_INT) :: length
    CHARACTER(LEN=BUFFER_SIZE) :: buffer

    length = Fieldml_CopyMarkupAttributeValue( fmlHandle, object, attribute//NUL, buffer, BUFFER_SIZE )

    FieldmlInput_HasMarkup = ( INDEX( buffer, value ) == 1 )

    err = FML_ERR_NO_ERROR

  END FUNCTION FieldmlInput_HasMarkup

  !
  !================================================================================================================================
  !

  FUNCTION FieldmlInput_IsElementEvaluatorCompatible( fmlHandle, object, err )
    !Arguments
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: object
    INTEGER(INTG), INTENT(OUT) :: err

    LOGICAL :: FieldmlInput_IsElementEvaluatorCompatible

    INTEGER(C_INT) :: type, length, evaluatorHandle
    CHARACTER(LEN=BUFFER_SIZE) :: name

    type = Fieldml_GetObjectType( fmlHandle, object )
    IF( type /= FHT_CONTINUOUS_REFERENCE ) THEN
      FieldmlInput_IsElementEvaluatorCompatible = .FALSE.
      RETURN
    ENDIF

    evaluatorHandle = Fieldml_GetReferenceRemoteEvaluator( fmlHandle, object )
    length = Fieldml_CopyObjectName( fmlHandle, evaluatorHandle, name, BUFFER_SIZE )

    IF( INDEX( name, 'library.fem.trilinear_lagrange' ) == 1 ) THEN
      FieldmlInput_IsElementEvaluatorCompatible = .TRUE.
    ELSE IF( INDEX( name, 'library.fem.triquadratic_lagrange' ) == 1 ) THEN
      FieldmlInput_IsElementEvaluatorCompatible = .TRUE.
    ELSE
      FieldmlInput_IsElementEvaluatorCompatible = .FALSE.
    ENDIF

    err = FML_ERR_NO_ERROR

  END FUNCTION FieldmlInput_IsElementEvaluatorCompatible

  !
  !================================================================================================================================
  !

  FUNCTION FieldmlInput_IsTemplateCompatible( fmlHandle, object, elementDomain, err )
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: object
    INTEGER(C_INT), INTENT(IN) :: elementDomain
    INTEGER(INTG), INTENT(OUT) :: err

    LOGICAL :: FieldmlInput_IsTemplateCompatible

    INTEGER(C_INT) :: type, count, i, evaluator, domain, firstEvaluator

    type = Fieldml_GetObjectType( fmlHandle, object )
    IF( type /= FHT_CONTINUOUS_PIECEWISE ) THEN
      FieldmlInput_IsTemplateCompatible = .FALSE.
      RETURN
    ENDIF

    domain = Fieldml_GetIndexDomain( fmlHandle, object, 1 )
    IF( domain /= elementDomain ) THEN
      FieldmlInput_IsTemplateCompatible = .TRUE.
      RETURN
    ENDIF

    count = Fieldml_GetEvaluatorCount( fmlHandle, object )

    IF( count == 0 ) THEN
      FieldmlInput_IsTemplateCompatible = .FALSE.
      RETURN
    ENDIF

    firstEvaluator = Fieldml_GetEvaluator( fmlHandle, object, 1 )
    IF( .NOT. FieldmlInput_IsElementEvaluatorCompatible( fmlHandle, firstEvaluator, err ) ) THEN
      FieldmlInput_IsTemplateCompatible = .FALSE.
      RETURN
    ENDIF

    !At the moment, the code does not support different evaluators per element.

    DO i = 2, count
      evaluator = Fieldml_GetEvaluator( fmlHandle, object, i )
      IF( evaluator /= firstEvaluator ) THEN
        FieldmlInput_IsTemplateCompatible = .FALSE.
        RETURN
      ENDIF
    ENDDO

    FieldmlInput_IsTemplateCompatible = .TRUE.

  END FUNCTION FieldmlInput_IsTemplateCompatible

  !
  !================================================================================================================================
  !

  FUNCTION FieldmlInput_IsFieldCompatible( fmlHandle, object, elementDomain, err )
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: object
    INTEGER(C_INT), INTENT(IN) :: elementDomain
    INTEGER(INTG), INTENT(OUT) :: err

    LOGICAL :: FieldmlInput_IsFieldCompatible

    INTEGER(C_INT) :: type, count, i, evaluator

    type = Fieldml_GetObjectType( fmlHandle, object )

    IF( type /= FHT_CONTINUOUS_AGGREGATE ) THEN
      FieldmlInput_IsFieldCompatible = .FALSE.
      RETURN
    ENDIF

    count = Fieldml_GetEvaluatorCount( fmlHandle, object )
    IF( count < 1 ) THEN
      FieldmlInput_IsFieldCompatible = .FALSE.
      RETURN
    ENDIF

    FieldmlInput_IsFieldCompatible = .TRUE.
    DO i = 1, count
      evaluator = Fieldml_GetEvaluator( fmlHandle, object, i )
      IF( .NOT. FieldmlInput_IsTemplateCompatible( fmlHandle, evaluator, elementDomain, err ) ) THEN
        FieldmlInput_IsFieldCompatible = .FALSE.
        RETURN
      ENDIF
    ENDDO

  END FUNCTION FieldmlInput_IsFieldCompatible

  !
  !================================================================================================================================
  !

  SUBROUTINE Fieldml_GetFieldHandles( fmlHandle, fieldHandles, meshHandle, err )
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), ALLOCATABLE :: fieldHandles(:)
    INTEGER(C_INT), INTENT(IN) :: meshHandle
    INTEGER(INTG), INTENT(OUT) :: err

    INTEGER(C_INT) :: count, i, object, fieldCount, elementDomain

    CALL ENTERS( "Fieldml_GetFieldHandles", err, errorString, *999 )

    elementDomain = Fieldml_GetMeshElementDomain( fmlHandle, meshHandle )
    CALL FieldmlUtil_CheckError( "Cannot get mesh element domain", fmlHandle, errorString, *999 )

    fieldCount = 0
    count = Fieldml_GetObjectCount( fmlHandle, FHT_CONTINUOUS_AGGREGATE )
    CALL FieldmlUtil_CheckError( "Cannot find any aggregate evaluators", fmlHandle, errorString, *999 )
    DO i = 1, count
      object = Fieldml_GetObject( fmlHandle, FHT_CONTINUOUS_AGGREGATE, i )
      CALL FieldmlUtil_CheckError( "Cannot get aggregate evaluator", fmlHandle, errorString, *999 )
      IF( .NOT. FieldmlInput_HasMarkup( fmlHandle, object, 'field', 'true', err ) ) THEN
        CYCLE
      ENDIF

      IF( .NOT. FieldmlInput_IsFieldCompatible( fmlHandle, object, elementDomain, err ) ) THEN
        CYCLE
      ENDIF

      CALL GROW_ARRAY( fieldHandles, 1, "", err, errorString, *999 )
      fieldCount = fieldCount + 1
      fieldHandles( fieldCount ) = object
    ENDDO

    CALL EXITS( "Fieldml_GetFieldHandles" )
    RETURN
999 CALL ERRORS( "Fieldml_GetFieldHandles", err, errorString )
    CALL EXITS( "Fieldml_GetFieldHandles" )
    CALL CMISS_HANDLE_ERROR( err, errorString )

  END SUBROUTINE Fieldml_GetFieldHandles


  !
  !================================================================================================================================
  !

  SUBROUTINE FieldmlInput_GetCoordinateSystemInfo( fmlHandle, evaluatorHandle, coordinateType, coordinateCount, err )
    !Arguments
    TYPE(C_PTR), INTENT(IN) :: fmlHandle
    INTEGER(C_INT), INTENT(IN) :: evaluatorHandle
    INTEGER(INTG), INTENT(OUT) :: coordinateType
    INTEGER(INTG), INTENT(OUT) :: coordinateCount
    INTEGER(INTG), INTENT(OUT) :: err

    !Locals
    INTEGER(C_INT) :: domainHandle, length
    CHARACTER(LEN=BUFFER_SIZE) :: name

    CALL ENTERS( "FieldmlInput_GetCoordinateSystemInfo", err, errorString, *999 )

    coordinateType = 0 !There doesn't seem to be a COORDINATE_UNKNOWN_TYPE

    domainHandle = Fieldml_GetValueDomain( fmlHandle, evaluatorHandle )
    CALL FieldmlUtil_CheckError( "Cannot get value domain for geometric field", fmlHandle, errorString, *999 )

    length = Fieldml_CopyObjectName( fmlHandle, domainHandle, name, BUFFER_SIZE )

    IF( INDEX( name, 'library.coordinates.rc.3d' ) == 1 ) THEN
      coordinateType = CMISSCoordinateRectangularCartesianType
      coordinateCount = 3
    ELSE IF( INDEX( name, 'library.coordinates.rc.2d' ) == 1 ) THEN
      coordinateType = CMISSCoordinateRectangularCartesianType
      coordinateCount = 2
    ELSE
      err = FML_ERR_UNKNOWN_COORDINATE_TYPE
      CALL FieldmlUtil_CheckError( "Coordinate system not yet supported", err, errorString, *999 )
    ENDIF

    CALL EXITS( "FieldmlInput_GetCoordinateSystemInfo" )
    RETURN
999 CALL ERRORS( "FieldmlInput_GetCoordinateSystemInfo", err, errorString )
    CALL EXITS( "FieldmlInput_GetCoordinateSystemInfo" )
    CALL CMISS_HANDLE_ERROR( err, errorString )

  END SUBROUTINE FieldmlInput_GetCoordinateSystemInfo


  !
  !================================================================================================================================
  !


  SUBROUTINE FieldmlInput_GetMeshInfo( fmlInfo, meshName, err )
    !Arguments
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fmlInfo
    CHARACTER(LEN=*), INTENT(IN) :: meshName
    INTEGER(INTG), INTENT(OUT) :: err

    !Locals
    INTEGER(INTG) :: count, i, handle

    CALL ENTERS( "FieldmlInput_GetMeshInfo", err, errorString, *999 )

    fmlInfo%meshHandle = Fieldml_GetNamedObject( fmlInfo%fmlHandle, meshName//NUL )
    IF( fmlInfo%meshHandle == FML_INVALID_HANDLE ) THEN
      err = Fieldml_GetLastError( fmlInfo%fmlHandle )
      CALL FieldmlUtil_CheckError( "Named mesh cannot be found", err, errorString, *999 )
    ENDIF
    
    fmlInfo%elementsHandle = Fieldml_GetMeshElementDomain( fmlInfo%fmlHandle, fmlInfo%meshHandle )
    fmlInfo%xiHandle = Fieldml_GetMeshXiDomain( fmlInfo%fmlHandle, fmlInfo%meshHandle )

    count = Fieldml_GetDomainComponentCount( fmlInfo%fmlHandle, fmlInfo%xiHandle )
    IF( ( count < 1 ) .OR. ( count > 3 ) ) THEN
      err = FML_ERR_UNKNOWN_MESH_XI
      CALL FieldmlUtil_CheckError( "Mesh dimension cannot be greater than 3, or less than 1", err, errorString, *999 )
    ENDIF

    count = Fieldml_GetMeshConnectivityCount( fmlInfo%fmlHandle, fmlInfo%meshHandle )

    IF( count == 0 ) THEN
      err = FML_ERR_INVALID_MESH
      CALL FieldmlUtil_CheckError( "Mesh must have connectivity information", err, errorString, *999 )
    END IF

    DO i = 1, count
      handle = Fieldml_GetMeshConnectivitySource( fmlInfo%fmlHandle, fmlInfo%meshHandle, i )
      IF( Fieldml_GetObjectType( fmlInfo%fmlHandle, handle ) /= FHT_ENSEMBLE_PARAMETERS ) THEN
        err = FML_ERR_INVALID_CONNECTIVITY
        CALL FieldmlUtil_CheckError( "Connectivity evaluator must be an ensemble parameters object", err, errorString, *999 )
      END IF

      IF( Fieldml_GetIndexCount( fmlInfo%fmlHandle, handle ) /= 2 ) THEN
        err = FML_ERR_INVALID_CONNECTIVITY
        CALL FieldmlUtil_CheckError( "Connectivity evaluator must only vary over two ensembles", err, errorString, *999 )
      END IF

      IF( ( Fieldml_GetIndexDomain( fmlInfo%fmlHandle, handle, 1 ) /= fmlInfo%elementsHandle ) .AND. &
        & ( Fieldml_GetIndexDomain( fmlInfo%fmlHandle, handle, 2 ) /= fmlInfo%elementsHandle ) ) THEN
        err = FML_ERR_INVALID_CONNECTIVITY
        CALL FieldmlUtil_CheckError( "Connectivity evaluator must vary over mesh elements domain", err, errorString, *999 )
      END IF
      
      IF( i == 1 ) THEN
        fmlInfo%nodesHandle = Fieldml_GetValueDomain( fmlInfo%fmlHandle, handle )
        IF( .NOT. FieldmlInput_HasMarkup( fmlInfo%fmlHandle, fmlInfo%nodesHandle, "geometric", "point", err ) ) THEN
          err = FML_ERR_INVALID_CONNECTIVITY
          CALL FieldmlUtil_CheckError( "Connectivity evaluator must vary over a geometric point ensemble", &
            & err, errorString, *999 )
        END IF      
      ELSE IF( fmlInfo%nodesHandle /= Fieldml_GetValueDomain( fmlInfo%fmlHandle, handle ) ) THEN
        err = FML_ERR_INVALID_CONNECTIVITY
        CALL FieldmlUtil_CheckError( "Connectivity evaluators must all vary over the same point ensemble", &
          & err, errorString, *999 )
      ENDIF

    END DO

    IF( fmlInfo%nodesHandle == FML_INVALID_HANDLE ) THEN
      err = FML_ERR_INVALID_CONNECTIVITY
      CALL FieldmlUtil_CheckError( "No valid point ensemble found for mesh connectivity", err, errorString, *999 )
    END IF

    CALL EXITS( "FieldmlInput_GetMeshInfo" )
    RETURN
999 CALL ERRORS( "FieldmlInput_GetMeshInfo", err, errorString )
    CALL EXITS( "FieldmlInput_GetMeshInfo" )
    CALL CMISS_HANDLE_ERROR( err, errorString )

  END SUBROUTINE FieldmlInput_GetMeshInfo

  !
  !================================================================================================================================
  !
  
  SUBROUTINE FieldmlInput_CreateBasis( fieldmlInfo, userNumber, evaluatorName, gaussQuadrature, err )
    !Arguments
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fieldmlInfo
    INTEGER(INTG), INTENT(IN) :: userNumber
    CHARACTER(LEN=*), INTENT(IN) :: evaluatorName
    INTEGER(INTG), INTENT(IN) :: gaussQuadrature(:)
    INTEGER(INTG), INTENT(OUT) :: err

    !Locals
    INTEGER(INTG) :: count, i
    INTEGER(C_INT) :: handle
    INTEGER(C_INT), ALLOCATABLE :: tempHandles(:)
    INTEGER(INTG) :: basisType
    INTEGER(INTG), ALLOCATABLE :: basisInterpolations(:)
    INTEGER(INTG), ALLOCATABLE :: collapse(:)
    
    CALL ENTERS( "FieldmlInput_CreateBasis", err, errorString, *999 )

    handle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, evaluatorName//NUL )
    CALL FieldmlUtil_CheckError( "Named basis not found", fieldmlInfo, errorString, *999 )
    CALL FieldmlInput_GetBasisInfo( fieldmlInfo, handle, basisType, basisInterpolations, collapse, err, *999 )
    
    IF( ALLOCATED( fieldmlInfo%basisHandles ) ) THEN
      count = SIZE( fieldmlInfo%basisHandles )
      DO i = 1, count
        IF( fieldmlInfo%basisHandles( i ) == handle ) THEN
          CALL FieldmlUtil_CheckError( "Named basis already created", fieldmlInfo, errorString, *999 )
        ENDIF
      END DO
      ALLOCATE( tempHandles( count ) )
      tempHandles(1:count) = fieldmlInfo%basisHandles(1:count)
      DEALLOCATE( fieldmlInfo%basisHandles )
      ALLOCATE( fieldmlInfo%basisHandles( count + 1 ) )
      fieldmlInfo%basisHandles(1:count) = tempHandles(1:count)
    ELSE
      count = 0
      ALLOCATE( fieldmlInfo%basisHandles( 1 ) )
    ENDIF
    
    count = count + 1
    fieldmlInfo%basisHandles( count ) = handle
    err = Fieldml_SetObjectInt( fieldmlInfo%fmlHandle, handle, userNumber )
  
    CALL CMISSBasisCreateStart( userNumber, err )
    CALL CMISSBasisTypeSet( userNumber, basisType, err )
    CALL CMISSBasisNumberOfXiSet( userNumber, size( basisInterpolations ), err )
    CALL CMISSBasisInterpolationXiSet( userNumber, basisInterpolations, err )
    CALL CMISSBasisCollapsedXiSet( userNumber, collapse, err )
    IF( SIZE( gaussQuadrature ) > 0 ) THEN
      CALL CMISSBasisQuadratureNumberOfGaussXiSet( userNumber, gaussQuadrature, err )
    ENDIF
    CALL CMISSBasisCreateFinish( userNumber, err )
    CALL FieldmlUtil_CheckError( "Cannot create basis", err, errorString, *999 )
    
    IF( ALLOCATED( basisInterpolations ) ) THEN
      DEALLOCATE( basisInterpolations )
    ENDIF
    IF( ALLOCATED( collapse ) ) THEN
      DEALLOCATE( collapse )
    ENDIF
  
    CALL EXITS( "FieldmlInput_CreateBasis" )
    RETURN
999 CALL ERRORS( "FieldmlInput_CreateBasis", err, errorString )
    CALL EXITS( "FieldmlInput_CreateBasis" )
    CALL CMISS_HANDLE_ERROR( err, errorString )

  END SUBROUTINE

  !
  !================================================================================================================================
  !

  SUBROUTINE FieldmlInput_InitializeFromFile( fieldmlInfo, filename, err )
    !Arguments
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fieldmlInfo
    CHARACTER(LEN=*), INTENT(IN) :: filename
    INTEGER(INTG), INTENT(OUT) :: err
    
    CALL ENTERS( "FieldmlInput_InitializeFromFile", err, errorString, *999 )

    fieldmlInfo%fmlHandle = Fieldml_CreateFromFile( filename//NUL )
    fieldmlInfo%nodesHandle = FML_INVALID_HANDLE
    fieldmlInfo%meshHandle = FML_INVALID_HANDLE
    fieldmlInfo%elementsHandle = FML_INVALID_HANDLE
    fieldmlInfo%xiHandle = FML_INVALID_HANDLE
    fieldmlInfo%nodeDofsHandle = FML_INVALID_HANDLE
    fieldmlInfo%elementDofsHandle = FML_INVALID_HANDLE
    fieldmlInfo%constantDofsHandle = FML_INVALID_HANDLE
    
    CALL FieldmlUtil_CheckError( "Cannot create FieldML handle from file", fieldmlInfo, errorString, *999 )

    CALL EXITS( "FieldmlInput_InitializeFromFile" )
    RETURN
999 CALL ERRORS( "FieldmlInput_InitializeFromFile", err, errorString )
    CALL EXITS( "FieldmlInput_InitializeFromFile" )
    CALL CMISS_HANDLE_ERROR( err, errorString )
    
  END SUBROUTINE FieldmlInput_InitializeFromFile

  !
  !================================================================================================================================
  !

  SUBROUTINE FieldmlInput_CreateMeshComponent( fieldmlInfo, regionNumber, meshNumber, componentNumber, evaluatorName, err )
    !Arguments
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fieldmlInfo
    INTEGER(INTG), INTENT(IN) :: regionNumber
    INTEGER(INTG), INTENT(IN) :: meshNumber
    INTEGER(INTG), INTENT(IN) :: componentNumber
    CHARACTER(LEN=*), INTENT(IN) :: evaluatorName
    INTEGER(INTG), INTENT(OUT) :: err
    
    !Locals
    INTEGER(C_INT) :: handle, basisReferenceHandle, connectivityHandle, layoutHandle, basisNumber, lastBasisHandle
    INTEGER(C_INT), ALLOCATABLE, TARGET :: nodesBuffer(:)
    INTEGER(C_INT), TARGET :: dummy(0)
    INTEGER(INTG), ALLOCATABLE :: tempHandles(:)
    INTEGER(INTG) :: componentCount, elementCount, knownBasisCount, maxBasisNodesCount, basisNodesCount
    INTEGER(INTG) :: elementNumber, knownBasisNumber
    TYPE(C_PTR), ALLOCATABLE :: connectivityReaders(:)
    TYPE(C_PTR) :: tPtr
    
    CALL ENTERS( "FieldmlInput_CreateMeshComponent", err, errorString, *999 )

    err = FML_ERR_NO_ERROR

    handle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, evaluatorName//NUL )
    IF( .NOT. FieldmlInput_IsTemplateCompatible( fieldmlInfo%fmlHandle, handle, fieldmlInfo%elementsHandle, err ) ) THEN
      err = FML_ERR_UNSUPPORTED
      CALL FieldmlUtil_CheckError( "Mesh component cannot be created from this evaluator", err, errorString, *999 )
    ENDIF

    IF( .NOT. ALLOCATED( fieldmlInfo%componentHandles ) ) THEN
      ALLOCATE( fieldmlInfo%componentHandles( componentNumber ) )
    ELSE IF( SIZE( fieldmlInfo%componentHandles ) < componentNumber ) THEN
      componentCount = SIZE( fieldmlInfo%componentHandles )
      ALLOCATE( tempHandles( componentCount ) )
      tempHandles(1:componentCount) = fieldmlInfo%componentHandles(1:componentCount)
      DEALLOCATE( fieldmlInfo%componentHandles )
      ALLOCATE( fieldmlInfo%componentHandles( componentNumber ) )
      fieldmlInfo%componentHandles(1:componentCount) = tempHandles(1:componentCount)
      fieldmlInfo%componentHandles(componentCount+1:componentNumber) = FML_INVALID_HANDLE
    ENDIF
    
    fieldmlInfo%componentHandles( componentNumber ) = handle
    
    knownBasisCount = SIZE( fieldmlInfo%basisHandles )
    ALLOCATE( connectivityReaders( knownBasisCount ) )
    
    maxBasisNodesCount = 0
    DO knownBasisNumber = 1, knownBasisCount
      CALL FieldmlInput_GetBasisConnectivityInfo( fieldmlInfo%fmlHandle, fieldmlInfo%meshHandle, &
        & fieldmlInfo%basisHandles(knownBasisNumber), connectivityHandle, layoutHandle, err, *999 )
        
      basisNodesCount = Fieldml_GetEnsembleDomainElementCount( fieldmlInfo%fmlHandle, layoutHandle )
      CALL FieldmlUtil_CheckError( "Cannot get local node count for layout", fieldmlInfo, errorString, *999 )

      IF( basisNodesCount > maxBasisNodesCount ) THEN
        maxBasisNodesCount = basisNodesCount
      ENDIF
      
      connectivityReaders(knownBasisNumber) = Fieldml_OpenReader( fieldmlInfo%fmlHandle, connectivityHandle )
      CALL FieldmlUtil_CheckError( "Cannot open connectivity reader", fieldmlInfo, errorString, *999 )
      
    END DO

    
    ALLOCATE( nodesBuffer( maxBasisNodesCount ) )

    elementCount = Fieldml_GetEnsembleDomainElementCount( fieldmlInfo%fmlHandle, fieldmlInfo%elementsHandle )
    CALL FieldmlUtil_CheckError( "Cannot get element count for mesh", fieldmlInfo, errorString, *999 )
    
    lastBasisHandle = FML_INVALID_HANDLE
    
    DO elementNumber = 1, elementCount
      basisReferenceHandle = Fieldml_GetElementEvaluator( fieldmlInfo%fmlHandle, handle, elementNumber, 1 )
      CALL FieldmlUtil_CheckError( "Cannot get element evaluator from mesh component", fieldmlInfo, errorString, *999 )
      
      IF( basisReferenceHandle /= lastBasisHandle ) THEN
        CALL FieldmlInput_GetBasisConnectivityInfo( fieldmlInfo%fmlHandle, fieldmlInfo%meshHandle, basisReferenceHandle, &
          & connectivityHandle, layoutHandle, err, *999 )
    
        basisNodesCount = Fieldml_GetEnsembleDomainElementCount( fieldmlInfo%fmlHandle, layoutHandle )
      CALL FieldmlUtil_CheckError( "Cannot get local node count for layout", fieldmlInfo, errorString, *999 )
      
        basisNumber = Fieldml_GetObjectInt( fieldmlInfo%fmlHandle, basisReferenceHandle )
        CALL FieldmlUtil_CheckError( "Cannot get basis user number for element evaluator", fieldmlInfo, errorString, *999 )
      ENDIF

      IF( elementNumber == 1 ) THEN
        CALL CMISSMeshElementsCreateStart( regionNumber, meshNumber, componentNumber, basisNumber, err )
        CALL FieldmlUtil_CheckError( "Cannot create mesh elements", err, errorString, *999 )
      ENDIF
      
      CALL CMISSMeshElementsBasisSet( regionNumber, meshNumber, componentNumber, elementNumber, basisNumber, err )
      CALL FieldmlUtil_CheckError( "Cannot set element basis", err, errorString, *999 )
      
      DO knownBasisNumber = 1, knownBasisCount
        !BUGFIX Intel compiler will explode if we don't use a temporary variable
        tPtr = connectivityReaders(knownBasisNumber)
        err = Fieldml_ReadIntSlice( fieldmlInfo%fmlHandle, tPtr, C_LOC(dummy), &
          & C_LOC(nodesBuffer) )
        CALL FieldmlUtil_CheckError( "Error reading connectivity", err, errorString, *999 )
        IF( fieldmlInfo%basisHandles(knownBasisNumber) == basisReferenceHandle ) THEN
          CALL CMISSMeshElementsNodesSet( regionNumber, meshNumber, componentNumber, elementNumber, &
            & nodesBuffer(1:basisNodesCount), err )
        ENDIF
      ENDDO
  
    END DO
    
    DO knownBasisNumber = 1, knownBasisCount
      !BUGFIX Intel compiler will explode if we don't use a temporary variable
      tPtr = connectivityReaders(knownBasisNumber)
      err = Fieldml_CloseReader( fieldmlInfo%fmlHandle, tPtr )
      CALL FieldmlUtil_CheckError( "Error closing connectivity reader", err, errorString, *999 )
    ENDDO
    
    DEALLOCATE( nodesBuffer )
  
    DEALLOCATE( connectivityReaders )
    
    CALL CMISSMeshElementsCreateFinish( regionNumber, meshNumber, componentNumber, err )
    
    err = Fieldml_SetObjectInt( fieldmlInfo%fmlHandle, handle, componentNumber )

    CALL EXITS( "FieldmlInput_CreateMeshComponent" )
    RETURN
999 CALL ERRORS( "FieldmlInput_CreateMeshComponent", err, errorString )
    CALL EXITS( "FieldmlInput_CreateMeshComponent" )
    CALL CMISS_HANDLE_ERROR( err, errorString )

  ENDSUBROUTINE

  !
  !================================================================================================================================
  !

  SUBROUTINE FieldmlInput_SetDofVariables( fieldmlInfo, nodeDofsName, elementDofsName, constantDofsName, err )
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fieldmlInfo
    CHARACTER(LEN=*), INTENT(IN) :: nodeDofsName
    CHARACTER(LEN=*), INTENT(IN) :: elementDofsName
    CHARACTER(LEN=*), INTENT(IN) :: constantDofsName
    INTEGER(INTG), INTENT(OUT) :: err
    
    CALL ENTERS( "FieldmlInput_SetDofVariables", err, errorString, *999 )

    !Some of these may not actually exist, but that's OK because that means they're not used.
    fieldmlInfo%nodeDofsHandle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, nodeDofsName//NUL )
    fieldmlInfo%elementDofsHandle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, elementDofsName//NUL )
    fieldmlInfo%constantDofsHandle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, constantDofsName//NUL )
    
    CALL EXITS( "FieldmlInput_SetDofVariables" )
    RETURN
999 CALL ERRORS( "FieldmlInput_SetDofVariables", err, errorString )
    CALL EXITS( "FieldmlInput_SetDofVariables" )
    CALL CMISS_HANDLE_ERROR( err, errorString )
  
  END SUBROUTINE

  !
  !================================================================================================================================
  !
  
  SUBROUTINE FieldmlInput_CreateField( fieldmlInfo, region, mesh, decomposition, fieldNumber, field, evaluatorName, err )
    !Arguments
    TYPE(FieldmlInfoType), INTENT(INOUT) :: fieldmlInfo
    TYPE(CMISSRegionType), INTENT(IN) :: region
    TYPE(CMISSMeshType), INTENT(IN) :: mesh
    TYPE(CMISSDecompositionType), INTENT(IN) :: decomposition
    INTEGER(INTG), INTENT(IN) :: fieldNumber
    TYPE(CMISSFieldType), INTENT(INOUT) :: field
    CHARACTER(LEN=*), INTENT(IN) :: evaluatorName
    INTEGER(INTG), INTENT(OUT) :: err
    
    !Locals
    INTEGER(C_INT) :: fieldHandle, templateHandle, nodalDofsHandle, domainHandle
    INTEGER(INTG) :: componentNumber, templateComponentNumber, nodeNumber, fieldDimensions, meshNodeCount
    INTEGER(INTG), ALLOCATABLE :: componentNumbers(:)
    LOGICAL :: nodeExists
    REAL(C_DOUBLE), ALLOCATABLE, TARGET :: buffer(:)
    INTEGER(C_INT), TARGET :: dummy(0)
    TYPE(C_PTR) :: reader

    CALL ENTERS( "FieldmlInput_CreateField", err, errorString, *999 )

    fieldHandle = Fieldml_GetNamedObject( fieldmlInfo%fmlHandle, evaluatorName//NUL )
    CALL FieldmlUtil_CheckError( "Cannot get named field evaluator", fieldmlInfo, errorString, *999 )
    domainHandle = Fieldml_GetValueDomain( fieldmlInfo%fmlHandle, fieldHandle )
    CALL FieldmlUtil_CheckError( "Cannot get named field evaluator's value domain", fieldmlInfo, errorString, *999 )
    fieldDimensions = Fieldml_GetDomainComponentCount( fieldmlInfo%fmlHandle, domainHandle )
    CALL FieldmlUtil_CheckError( "Cannot get named field evaluator's component count", fieldmlInfo, errorString, *999 )
    
    IF( .NOT. FieldmlInput_IsFieldCompatible( fieldmlInfo%fmlHandle, fieldHandle, fieldmlInfo%elementsHandle, err ) ) THEN
      err = FML_ERR_INVALID_OBJECT
      CALL FieldmlUtil_CheckError( "Cannot interpret given evaluator as a field", fieldmlInfo, errorString, *999 )
    ENDIF

    CALL CMISSFieldTypeInitialise( field, err )
    CALL CMISSFieldCreateStart( fieldNumber, region, field, err )
    CALL CMISSFieldTypeSet( field, CMISSFieldGeometricType, err )
    CALL CMISSFieldMeshDecompositionSet( field, decomposition, err )
    CALL CMISSFieldScalingTypeSet( field, CMISSFieldNoScaling, err )
    CALL FieldmlUtil_CheckError( "Cannot create new field", err, errorString, *999 )

    ALLOCATE( componentNumbers( fieldDimensions ) )
    DO componentNumber = 1, fieldDimensions
      templateHandle = Fieldml_GetElementEvaluator( fieldmlInfo%fmlHandle, fieldHandle, componentNumber, 1 )
      CALL FieldmlUtil_CheckError( "Cannot get field component evaluator", fieldmlInfo, errorString, *999 )

      templateComponentNumber = Fieldml_GetObjectInt( fieldmlInfo%fmlHandle, templateHandle )
      CALL FieldmlUtil_CheckError( "Cannot get field component mesh component number", fieldmlInfo, errorString, *999 )

      CALL CMISSFieldComponentMeshComponentSet( field, CMISSFieldUVariableType, componentNumber, templateComponentNumber, err )
      CALL FieldmlUtil_CheckError( "Cannot set field component mesh component number", err, errorString, *999 )

      componentNumbers( componentNumber ) = templateComponentNumber
    ENDDO

    CALL CMISSFieldCreateFinish( field, err )
    CALL FieldmlUtil_CheckError( "Cannot finish field", err, errorString, *999 )

    nodalDofsHandle = Fieldml_GetAliasByRemote( fieldmlInfo%fmlHandle, fieldHandle, fieldmlInfo%nodeDofsHandle )
    CALL FieldmlUtil_CheckError( "Cannot get nodal field dofs", fieldmlInfo, errorString, *999 )
  
    reader = Fieldml_OpenReader( fieldmlInfo%fmlHandle, nodalDofsHandle )
    CALL FieldmlUtil_CheckError( "Cannot open nodal dofs reader", fieldmlInfo, errorString, *999 )
    IF( C_ASSOCIATED( reader ) ) THEN
      ALLOCATE( buffer( fieldDimensions ) )
      
      meshNodeCount = Fieldml_GetEnsembleDomainElementCount( fieldmlInfo%fmlHandle, fieldmlInfo%nodesHandle )
      CALL FieldmlUtil_CheckError( "Cannot get mesh nodes count", fieldmlInfo, errorString, *999 )
      DO nodeNumber = 1, meshNodeCount
        err = Fieldml_ReadDoubleSlice( fieldmlInfo%fmlHandle, reader, C_LOC(dummy), C_LOC(buffer) )
        CALL FieldmlUtil_CheckError( "Cannot read nodal dofs for field components", err, errorString, *999 )

        DO componentNumber = 1, fieldDimensions
          CALL CMISSMeshNodeExists( mesh, componentNumbers( componentNumber ), nodeNumber, nodeExists, err )
          CALL FieldmlUtil_CheckError( "Error checking mesh node existance", err, errorString, *999 )
  
          IF( nodeExists ) THEN
            CALL CMISSFieldParameterSetUpdateNode( field, CMISSFieldUVariableType,CMISSFieldValuesSetType, & 
              & CMISSNoGlobalDerivative, nodeNumber, componentNumber, buffer( componentNumber ), err )
            CALL FieldmlUtil_CheckError( "Error set nodal dof value", err, errorString, *999 )
          ENDIF
        ENDDO
      ENDDO
    
      DEALLOCATE( buffer )
  
      err = Fieldml_CloseReader( fieldmlInfo%fmlHandle, reader )
      CALL FieldmlUtil_CheckError( "Cannot close nodal dofs reader", err, errorString, *999 )

      CALL CMISSFieldParameterSetUpdateStart( field, CMISSFieldUVariableType, CMISSFieldValuesSetType, err )
      CALL CMISSFieldParameterSetUpdateFinish( field, CMISSFieldUVariableType, CMISSFieldValuesSetType, err )
      CALL FieldmlUtil_CheckError( "Error updating field parameter set", err, errorString, *999 )
    ENDIF

    !TODO Set element and constant parameters
    
    DEALLOCATE( componentNumbers )

    CALL EXITS( "FieldmlInput_CreateField" )
    RETURN
999 CALL ERRORS( "FieldmlInput_CreateField", err, errorString )
    CALL EXITS( "FieldmlInput_CreateField" )
    CALL CMISS_HANDLE_ERROR( err, errorString )
  
  END SUBROUTINE

  !
  !================================================================================================================================
  !

END MODULE FIELDML_INPUT_ROUTINES