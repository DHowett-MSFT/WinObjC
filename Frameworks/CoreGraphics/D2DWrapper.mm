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

#import <CoreGraphics/D2DWrapper.h>
#import <Starboard.h>

using namespace Microsoft::WRL;

HRESULT _CGGetD2DFactory(ID2D1Factory** factory) {
    static ComPtr<ID2D1Factory> sFactory;
    static HRESULT sHr = D2D1CreateFactory(D2D1_FACTORY_TYPE_MULTI_THREADED, __uuidof(ID2D1Factory), &sFactory);
    sFactory.CopyTo(factory);
    RETURN_HR(sHr);
}

HRESULT _CGGetWICFactory(IWICImagingFactory** factory) {
    static ComPtr<IWICImagingFactory> sWicFactory;
    static HRESULT sHr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&sWicFactory));
    sWicFactory.CopyTo(factory);
    RETURN_HR(sHr);
}

// TODO GH#1375: Remove this when CGPath's fill mode has been worked out.
HRESULT _CGConvertD2DGeometryToFillMode(ID2D1Geometry* geometry, D2D1_FILL_MODE fillMode, ID2D1Geometry** pNewGeometry) {
    ComPtr<ID2D1Factory> factory;
    geometry->GetFactory(&factory);

    ComPtr<ID2D1GeometryGroup> geometryGroup;
    RETURN_IF_FAILED(factory->CreateGeometryGroup(fillMode, &geometry, 1, &geometryGroup));

    ComPtr<ID2D1Geometry> outGeometry;
    RETURN_IF_FAILED(geometryGroup.As(&outGeometry));

    *pNewGeometry = outGeometry.Detach();
    return S_OK;
}

AxisAlignedRectangleChecker::AxisAlignedRectangleChecker()
    : m_fPathOpened(true),
      m_fFigureOpened(false),
      m_fDefinitelyNotRectangle(false),
      m_fConfirmedRectangle(false),
      m_uFigureNum(0),
      m_cLines(0) {
}

void AxisAlignedRectangleChecker::AddLines(_In_reads_(pointsCount) const D2D1_POINT_2F* points, unsigned int pointsCount) {
    if (m_fDefinitelyNotRectangle) {
        return;
    }

    unsigned int cNewLines = pointsCount;

    //
    // Make sure we won't pass 4 lines.
    //
    if (m_cLines + cNewLines > 4) {
        m_fDefinitelyNotRectangle = true;
        return;
    }

    //
    // Copy the points.
    //

    //
    // We record a start point at m_rgLinesPoints[0], and since each line is
    // defined with 1 additional point, we're always copying to index:
    // m_cLines + 1
    //

    memcpy(&m_rgLinePoints[m_cLines + 1], points, sizeof(points[0]) * pointsCount);

    m_cLines += cNewLines;
}

HRESULT AxisAlignedRectangleChecker::Close() {
    HRESULT hr = S_OK;

    if (m_fDefinitelyNotRectangle) {
        goto Cleanup;
    }

    //
    // In general, geometries that have rectangular fills with have either
    // 3 or 4 segments. Geometries with more segments can also have
    // rectangular fills, but we don't care about those
    // cases.
    //

    if ((m_cLines == 4) && (m_rgLinePoints[4].x == m_rgLinePoints[0].x) && (m_rgLinePoints[4].y == m_rgLinePoints[0].y)) {
        m_cLines = 3;
    }

    if (m_cLines != 3) {
        m_fDefinitelyNotRectangle = true;
        goto Cleanup;
    }

    // Traverse all four segments, starting with the first horizontal edge
    // These four segments should alternate which coordinate changes
    unsigned int startSide = (m_rgLinePoints[0].y == m_rgLinePoints[1].y) ? 0 : 1;

    if ((m_rgLinePoints[startSide + 0].y != m_rgLinePoints[startSide + 1].y) ||
        (m_rgLinePoints[startSide + 1].x != m_rgLinePoints[startSide + 2].x) ||
        (m_rgLinePoints[startSide + 2].y != m_rgLinePoints[(startSide + 3) % 4].y) ||
        (m_rgLinePoints[(startSide + 3) % 4].x != m_rgLinePoints[(startSide + 4) % 4].x)) {
        m_fDefinitelyNotRectangle = true;
        goto Cleanup;
    }

    m_fConfirmedRectangle = true;

Cleanup:
    m_fPathOpened = false;

    return hr;
}