'use client'
import { useQuery } from '@tanstack/react-query'
import { APIProvider, Map, AdvancedMarker } from '@vis.gl/react-google-maps'

interface StationDto {
  id: number; name: string
  densityLevel: string; density: number
  lat: number; lng: number
}

const densityColor: Record<string, string> = {
  Low:      'var(--crowd-low)',
  Moderate: 'var(--crowd-moderate)',
  High:     'var(--crowd-high)',
  VeryHigh: 'var(--crowd-full)',
}

export default function AppMapPage() {
  const { data: stations = [] } = useQuery<StationDto[]>({
    queryKey: ['stations'],
    queryFn: () => fetch('/api/proxy/stations').then(r => r.json()),
    refetchInterval: 30_000,
  })

  return (
    <div className="h-screen w-full">
      <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
        <Map
          defaultCenter={{ lat: -23.55, lng: -46.63 }}
          defaultZoom={11}
          mapId="trilho-map"
          className="h-full w-full"
        >
          {stations.map(s => (
            <AdvancedMarker key={s.id} position={{ lat: s.lat, lng: s.lng }}>
              <div
                className="w-3 h-3 rounded-full border-2 border-white shadow"
                style={{ backgroundColor: densityColor[s.densityLevel] ?? '#6b7280' }}
                title={s.name}
              />
            </AdvancedMarker>
          ))}
        </Map>
      </APIProvider>
    </div>
  )
}
