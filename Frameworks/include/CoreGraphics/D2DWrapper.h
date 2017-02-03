//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#pragma once

#include <COMIncludes.h>
#import <WRLHelpers.h>
#import <wrl/client.h>
#import <D2d1.h>
#import "Wincodec.h"
#include <COMIncludes_End.h>

#import <CoreGraphics/CGAffineTransform.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGBase.h>

HRESULT _CGGetD2DFactory(ID2D1Factory** factory);

HRESULT _CGGetWICFactory(IWICImagingFactory** factory);

HRESULT _CGConvertD2DGeometryToFillMode(ID2D1Geometry* geometry, D2D1_FILL_MODE fillMode, ID2D1Geometry** pNewGeometry);

inline D2D_POINT_2F _CGPointToD2D_F(CGPoint point) {
    return { point.x, point.y };
}

inline CGPoint _D2DPointToCGPoint(D2D_POINT_2F point) {
    return { point.x, point.y };
}

inline CGRect _D2DRectToCGRect(D2D1_RECT_F rect) {
    CGFloat x = rect.left;
    CGFloat y = rect.top;
    CGFloat width = rect.right - x;
    CGFloat height = rect.bottom - y;

    return { { x, y }, { width, height } };
}

inline D2D1_MATRIX_3X2_F __CGAffineTransformToD2D_F(CGAffineTransform transform) {
    return { transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty };
}

inline D2D_RECT_F __CGRectToD2D_F(CGRect rect) {
    return {
        rect.origin.x, rect.origin.y, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height,
    };
}

class AxisAlignedRectangleChecker : public ID2D1SimplifiedGeometrySink {
public:
    AxisAlignedRectangleChecker();

    bool IsAxisAlignedRectangle() const {
        return m_fConfirmedRectangle;
    }

    STDMETHOD_(void, SetFillMode)(D2D1_FILL_MODE fillMode) {
        return;
    }

    STDMETHOD_(void, SetSegmentFlags)(D2D1_PATH_SEGMENT vertexFlags) {
        return;
    }

    STDMETHOD_(void, EndFigure)(D2D1_FIGURE_END figureEnd) {
        m_fFigureOpened = false;
        m_uFigureNum++;
    }

    STDMETHOD_(void, BeginFigure)(D2D1_POINT_2F startPoint, D2D1_FIGURE_BEGIN figureBegin) {
        m_fFigureOpened = true;

        //
        // If we're not considered a filled shape or we've already added a
        // figure, then we're not a rectangle.
        //
        if (figureBegin != D2D1_FIGURE_BEGIN_FILLED || m_uFigureNum != 0) {
            m_fDefinitelyNotRectangle = true;
        }

        m_rgLinePoints[0] = startPoint;
    }

    STDMETHOD_(void, AddLines)(const D2D1_POINT_2F* points, unsigned int pointsCount);

    STDMETHOD_(void, AddBeziers)(const D2D1_BEZIER_SEGMENT* beziers, unsigned int beziersCount) {
        //
        // If any beziers are added, then we're definitely not a rectangle.
        //
        m_fDefinitelyNotRectangle = true;
    }

    STDMETHOD(Close)();

    STDMETHOD_(ULONG, AddRef)() {
        return 0;
    }

    STDMETHOD_(ULONG, Release)() {
        return 0;
    }

    //
    // IUnknown methods
    //
    STDMETHOD(QueryInterface)(REFIID riid, void** ppv) {
        return E_NOTIMPL;
    }

private:
    bool m_fPathOpened;
    bool m_fFigureOpened;

    unsigned int m_uFigureNum;

    unsigned int m_cLines;

    //
    // We keep 5 points to make it easier to store for 4 connected lines.  At
    // the end we will verify the last point is equal to the first.
    //
    D2D1_POINT_2F m_rgLinePoints[5];

    bool m_fDefinitelyNotRectangle;
    bool m_fConfirmedRectangle;
};